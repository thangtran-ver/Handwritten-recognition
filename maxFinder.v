// maxFinder.v (da sua loi: thieu always block, thua "end")
module maxFinder #(parameter numInput=10, parameter inputWidth=16)(
    input wire clk,
    input  [(numInput*inputWidth)-1:0] i_data,   // gom du lieu 10 neuron output cuoi
    input  i_valid,
    output reg [31:0] o_data,       // chi so (index) cua neuron co gia tri lon nhat = digit nhan dien duoc
    output reg o_data_valid
);
    reg [inputWidth-1:0] maxValue;
    reg [(numInput*inputWidth)-1:0] inDataBuffer;
    integer counter;

    always @(posedge clk) begin
        o_data_valid <= 1'b0;   // mac dinh, chi len 1 dung 1 chu ky khi tim xong

        if (i_valid) begin
            maxValue     <= i_data[inputWidth-1:0];
            inDataBuffer <= i_data;
            counter      <= 1;
            o_data       <= 0;
        end
        else if (counter != 0 && counter < numInput) begin
            if (inDataBuffer[counter*inputWidth+:inputWidth] > maxValue) begin
                maxValue <= inDataBuffer[counter*inputWidth+:inputWidth];
                o_data   <= counter;
            end
            counter <= counter + 1;
            if (counter == numInput-1)
                o_data_valid <= 1'b1;   // da so sanh het 10 neuron, ket qua san sang
        end
    end
endmodule
