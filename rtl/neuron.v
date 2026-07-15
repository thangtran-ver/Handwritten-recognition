`include "include.v"
module neuron #(parameter layerNo=0,neuronNo=0,numWeight=784,dataWidth=16,sigmoidSize=10,weightIntWidth=4,actType="sigmoid",biasFile="",weightFile="")(
    input           clk,                // clock hệ thống
    input           reset_n,              // reset, tích cực mức thấp (active low)
    input [dataWidth-1:0]    myinput,        // giá trị input (1 phần tử, đưa vào tuần tự từng nhịp)
    input           myinputValid,       // báo myinput hiện tại có hợp lệ để xử lý không
    input           weightValid,        // báo weightValue hiện tại có hợp lệ để ghi vào RAM không
    input           biasValid,          // báo biasValue hiện tại có hợp lệ để nạp không
    input [31:0]    weightValue,        // giá trị weight cần ghi vào RAM (khi đang nạp trọng số)
    input [31:0]    biasValue,          // giá trị bias cần nạp cho neuron này
    input [31:0]    config_layer_num,   // số layer đang được cấu hình/nạp (để neuron so khớp có phải lượt mình không)
    input [31:0]    config_neuron_num,  // số neuron đang được cấu hình/nạp (so khớp cùng layerNo/neuronNo)
    output[dataWidth-1:0]    out,        // kết quả output sau activation
    output reg      outvalid            // báo out hiện tại đã tính xong, hợp lệ để đọc
    );
	 parameter addressWidth = $clog2(numWeight);


    reg         wen;                    // cho phép ghi (write enable) vào RAM trọng số
    wire        ren;                    // cho phép đọc (read enable) RAM trọng số
    reg [addressWidth-1:0] w_addr;       // địa chỉ ghi trọng số (tăng dần khi nạp)
    reg [addressWidth:0]   r_addr;       // địa chỉ đọc trọng số (tăng dần khi tính toán); rộng hơn 1 bit vì cần đếm tới numWeight (785 giá trị: 0..784)
    reg [dataWidth-1:0]  w_in;           // dữ liệu ghi vào RAM (lấy từ weightValue)
    wire [dataWidth-1:0] w_out;          // dữ liệu đọc ra từ RAM (trọng số tương ứng với input hiện tại)
    reg [2*dataWidth-1:0]  mul;          // kết quả phép nhân input × weight (rộng gấp đôi để tránh tràn)
    reg [2*dataWidth-1:0]  sum;          // tổng tích luỹ (accumulator), cộng dồn qua từng input
    reg [2*dataWidth-1:0]  bias;         // giá trị bias đã được nạp, dùng để cộng vào sum ở bước cuối
    reg [31:0]    biasReg[0:0];          // thanh ghi/ROM tạm giữ bias đọc từ file (dùng khi có sẵn trọng số pretrained)
    reg         weight_valid;            // cờ valid trễ 1 nhịp so với myinputValid (đồng bộ với độ trễ đọc RAM)
    reg         mult_valid;              // cờ valid trễ thêm 1 nhịp nữa (đồng bộ với độ trễ phép nhân)
    wire        mux_valid;               // cờ báo kết quả mul hiện tại đã sẵn sàng để cộng dồn vào sum
    reg         sigValid;                // cờ báo sum cuối cùng đã sẵn sàng để đưa qua activation
    wire [2*dataWidth:0] comboAdd;        // kết quả cộng dồn: mul + sum (dùng khi đang tích luỹ qua từng input)
    wire [2*dataWidth:0] BiasAdd;         // kết quả cộng bias: bias + sum (dùng 1 lần duy nhất ở bước cuối)
    reg  [dataWidth-1:0] myinputd;         // input đã trễ 1 nhịp, để đồng bộ đúng lúc với w_out khi đưa vào bộ nhân
    reg muxValid_d;                       // mux_valid trễ 1 nhịp
    reg muxValid_f;                       // cờ phát hiện cạnh xuống của mux_valid (dùng để nhận biết đúng thời điểm input cuối cùng đã cộng dồn xong)
    reg addr=0;                           // địa chỉ dùng để đọc biasReg (trường hợp dùng bias pretrained từ file)

	 // load weights vao memory
	 always @(posedge clk) begin
	 if (reset_n == 	1'b0) begin
	 wen <= 1'b0;
	 w_addr <= {addressWidth{1'b1}};
	 end
	 else if(weightValid & (config_layer_num==layerNo) & (config_neuron_num==neuronNo)) begin
	 wen <= 1'b1;
	 w_in <= weightValue;
	 w_addr <= w_addr +1;
	 end
	 else 
	 wen <= 1'b0;
end

    assign mux_valid = mult_valid;
    assign comboAdd = mul + sum;
    assign BiasAdd = bias + sum;
    assign ren = myinputValid;

    // ---- Nap bias ----
    // QUAN TRONG (bug da sua): bias file/register o dang Q5.11 (biasFracWidth=11).
    // Accumulator sum o dang Q5.27 (= input Q1.15 x weight Q4.12 -> 15+12=27 bit thap phan).
    // De cong dung scale, bias phai dich trai DUNG 16 bit (11+16=27 bit thap phan):
    //     bias = {bias16, 16'b0}
    // Ban loi truoc day ghep them sign-extension va chi dich 12 bit -> bias nho hon 16 lan.
    // Khong can sign-extension: bit cao nhat cua bias16 khi ghep {bias16,16'b0}
    // tro thanh bit 31 = bit dau cua so 32-bit bu 2 -> van dung dau.
	     `ifdef pretrained
        initial
        begin
            $readmemb(biasFile,biasReg);
        end
        always @(posedge clk)
        begin
            bias <= {biasReg[addr][dataWidth-1:0],{dataWidth{1'b0}}};
        end
    `else
        always @(posedge clk)
        begin
            if(biasValid & (config_layer_num==layerNo) & (config_neuron_num==neuronNo))
            begin
                bias <= {biasValue[dataWidth-1:0],{dataWidth{1'b0}}};
            end
        end
    `endif
// dem so input da xu ly
always @(posedge clk) begin
if(reset_n == 1'b0 | outvalid)
r_addr <= 0;
else if(myinputValid)
r_addr <= r_addr +1;
end
//phep nhan
always @(posedge clk) begin
mul <= $signed(myinputd) * $signed(w_out);
end
// cong don + cong bias + kiem tra tran so 
always @(posedge clk) begin
if(!reset_n || outvalid)
sum <= 0;
else if((r_addr == numWeight) && muxValid_f) begin
if(bias[2*dataWidth-1] ==0 && sum[2*dataWidth-1] ==0 && BiasAdd[2*dataWidth-1] ) begin
sum[2*dataWidth-1] <= 1'b0;
sum[2*dataWidth-2:0] <= {2*dataWidth-1{1'b1}};
end
else if(bias[2*dataWidth-1] ==1 && sum[2*dataWidth-1] ==1 && !BiasAdd[2*dataWidth-1] )
begin
sum[2*dataWidth-1] <= 1'b1;
sum[2*dataWidth-2:0] <= {2*dataWidth-1{1'b0}};
end
else sum <= BiasAdd;
end
else if(mux_valid) begin
if(mul[2*dataWidth-1] == 0 && sum[2*dataWidth-1] ==0 && comboAdd[2*dataWidth-1] ==1) begin
sum[2*dataWidth-1] <= 1'b0;
sum[2*dataWidth-2:0] <= {2*dataWidth-1{1'b1}};
end
else if(mul[2*dataWidth-1] == 1 && sum[2*dataWidth-1] ==1 && comboAdd[2*dataWidth-1] ==0) begin
sum[2*dataWidth-1] <= 1'b1; 
sum[2*dataWidth-2:0] <= {2*dataWidth-1{1'b0}};
end
else sum <= comboAdd;
end
end
always @(posedge clk) begin
myinputd <= myinput;
weight_valid <= myinputValid;
mult_valid <= weight_valid;
sigValid <= ((r_addr == numWeight) & muxValid_f) ? 1'b1 : 1'b0;
outvalid <= sigValid;
muxValid_d <= mux_valid;
muxValid_f <= !mux_valid & muxValid_d;
end
//Instantiation of Memory for Weights
    Weight_Memory #(.numWeight(numWeight),.neuronNo(neuronNo),.layerNo(layerNo),.addressWidth(addressWidth),.dataWidth(dataWidth),.weightFile(weightFile)) WM(
        .clk(clk),
        .wen(wen),
        .ren(ren),
        .wadd(w_addr),
        .radd(r_addr),
        .win(w_in),
        .wout(w_out)
    );
    
    generate
        if(actType == "sigmoid")
        begin:siginst
        //Instantiation of ROM for sigmoid
            Sig_ROM #(.inWidth(sigmoidSize),.dataWidth(dataWidth)) s1(
            .clk(clk),
            .x(sum[2*dataWidth-1-:sigmoidSize]),
            .out(out)
        );
        end
        else
        begin:ReLUinst
            ReLU #(.dataWidth(dataWidth),.weightIntWidth(weightIntWidth)) s1 (
            .clk(clk),
            .x(sum),
            .out(out)
        );
        end
    endgenerate

    `ifdef DEBUG
    always @(posedge clk)
    begin
        if(outvalid)
            $display(neuronNo,,,,"%b",out);
    end
    `endif
endmodule