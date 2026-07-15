`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: tb_batch
// Chay TU DONG nhieu file test lien tiep (giong top_sim.v goc) va tinh accuracy:
//   - Lap qua test_data_0000.txt ... test_data_XXXX.txt (MaxTestSamples file)
//   - Ten file tu sinh bang $sformat, khong can go tay
//   - Nhan ky vong doc tu dong 785 cua tung file
//   - In ket qua tung anh + accuracy luy ke + accuracy tong cuoi cung
//
// Doi so tuy chinh (khong can sua code):
//   vsim work.tb_batch +NUMTESTS=100      (mac dinh 10)
//
// Bien dich:
//   vlog rtl/Sig_ROM.v rtl/Weight_memory.v rtl/neuron.v rtl/Layer_1.v rtl/Layer_2.v rtl/Layer_3.v rtl/Layer_4.v rtl/maxFinder.v tb/tb_full.v
//   vsim work.tb_batch +NUMTESTS=10
//   run -all
//////////////////////////////////////////////////////////////////////////////////

module tb_batch();

    parameter dataWidth = 16;
    parameter NN1 = 30;
    parameter NN2 = 30;
    parameter NN3 = 10;
    parameter NN4 = 10;
    parameter numPixel = 784;

    reg clk;
    reg reset_n;

    // ---- Layer 1 ----
    reg                        x1_valid;
    reg  [dataWidth-1:0]       x1_in;
    wire [NN1-1:0]             o1_valid;
    wire [NN1*dataWidth-1:0]   x1_out;

    // ---- Serializer L1->L2 ----
    reg  [1:0]                 st1;
    localparam S_IDLE = 2'd0, S_SEND = 2'd1;
    reg  [NN1*dataWidth-1:0]   hold1;
    reg  [5:0]                 cnt1;
    reg                        x2_valid;
    reg  [dataWidth-1:0]       x2_in;

    // ---- Layer 2 ----
    wire [NN2-1:0]             o2_valid;
    wire [NN2*dataWidth-1:0]   x2_out;

    // ---- Serializer L2->L3 ----
    reg  [1:0]                 st2;
    reg  [NN2*dataWidth-1:0]   hold2;
    reg  [5:0]                 cnt2;
    reg                        x3_valid;
    reg  [dataWidth-1:0]       x3_in;

    // ---- Layer 3 ----
    wire [NN3-1:0]             o3_valid;
    wire [NN3*dataWidth-1:0]   x3_out;

    // ---- Serializer L3->L4 ----
    reg  [1:0]                 st3;
    reg  [NN3*dataWidth-1:0]   hold3;
    reg  [5:0]                 cnt3;
    reg                        x4_valid;
    reg  [dataWidth-1:0]       x4_in;

    // ---- Layer 4 ----
    wire [NN4-1:0]             o4_valid;
    wire [NN4*dataWidth-1:0]   x4_out;

    // ---- maxFinder ----
    wire [31:0]                digit;
    wire                       digit_valid;

    // ---- Chup output L4 dung thoi diem (Sig_ROM khong giu output) ----
    reg  [NN4*dataWidth-1:0]   l4_result;

    // ---- Du lieu ----
    reg  [dataWidth-1:0]       in_mem [numPixel:0];
    reg  [8*32-1:0]            fname;       // ten file dang chuoi (32 ky tu)
    integer                    numTests;
    integer                    p, t, i;
    integer                    expected_digit;
    integer                    right, wrong;

    //--------------------------------------------------------------------
    Layer_1 #(.NN(NN1), .numWeight(numPixel), .dataWidth(dataWidth),
              .sigmoidSize(10), .weightIntWidth(4), .actType("sigmoid"), .layerNum(1)) L1 (
        .clk(clk), .reset_n(reset_n),
        .x_valid(x1_valid), .x_in(x1_in),
        .o_valid(o1_valid), .x_out(x1_out));

    Layer_2 #(.NN(NN2), .numWeight(NN1), .dataWidth(dataWidth),
              .sigmoidSize(10), .weightIntWidth(4), .actType("sigmoid"), .layerNum(2)) L2 (
        .clk(clk), .reset_n(reset_n),
        .x_valid(x2_valid), .x_in(x2_in),
        .o_valid(o2_valid), .x_out(x2_out));

    Layer_3 #(.NN(NN3), .numWeight(NN2), .dataWidth(dataWidth),
              .sigmoidSize(10), .weightIntWidth(4), .actType("sigmoid"), .layerNum(3)) L3 (
        .clk(clk), .reset_n(reset_n),
        .x_valid(x3_valid), .x_in(x3_in),
        .o_valid(o3_valid), .x_out(x3_out));

    Layer_4 #(.NN(NN4), .numWeight(NN3), .dataWidth(dataWidth),
              .sigmoidSize(10), .weightIntWidth(4), .actType("sigmoid"), .layerNum(4)) L4 (
        .clk(clk), .reset_n(reset_n),
        .x_valid(x4_valid), .x_in(x4_in),
        .o_valid(o4_valid), .x_out(x4_out));

    maxFinder #(.numInput(NN4), .inputWidth(dataWidth)) MF (
        .clk(clk),
        .i_data(x4_out),
        .i_valid(o4_valid[0]),
        .o_data(digit),
        .o_data_valid(digit_valid));

    initial clk = 1'b0;
    always #5 clk = ~clk;

    //--------------------------------------------------------------------
    // 3 serializer (pattern: DANG KY out truoc khi shift)
    //--------------------------------------------------------------------
    always @(posedge clk) begin // L1 -> L2
        if (!reset_n) begin
            st1 <= S_IDLE; cnt1 <= 0; x2_valid <= 1'b0; x2_in <= 0;
        end else case (st1)
            S_IDLE: begin
                x2_valid <= 1'b0;
                if (o1_valid[0]) begin hold1 <= x1_out; cnt1 <= 0; st1 <= S_SEND; end
            end
            S_SEND: begin
                x2_in    <= hold1[dataWidth-1:0];
                x2_valid <= 1'b1;
                hold1    <= hold1 >> dataWidth;
                cnt1     <= cnt1 + 1;
                if (cnt1 == NN1-1) st1 <= S_IDLE;
            end
            default: st1 <= S_IDLE;
        endcase
    end

    always @(posedge clk) begin // L2 -> L3
        if (!reset_n) begin
            st2 <= S_IDLE; cnt2 <= 0; x3_valid <= 1'b0; x3_in <= 0;
        end else case (st2)
            S_IDLE: begin
                x3_valid <= 1'b0;
                if (o2_valid[0]) begin hold2 <= x2_out; cnt2 <= 0; st2 <= S_SEND; end
            end
            S_SEND: begin
                x3_in    <= hold2[dataWidth-1:0];
                x3_valid <= 1'b1;
                hold2    <= hold2 >> dataWidth;
                cnt2     <= cnt2 + 1;
                if (cnt2 == NN2-1) st2 <= S_IDLE;
            end
            default: st2 <= S_IDLE;
        endcase
    end

    always @(posedge clk) begin // L3 -> L4
        if (!reset_n) begin
            st3 <= S_IDLE; cnt3 <= 0; x4_valid <= 1'b0; x4_in <= 0;
        end else case (st3)
            S_IDLE: begin
                x4_valid <= 1'b0;
                if (o3_valid[0]) begin hold3 <= x3_out; cnt3 <= 0; st3 <= S_SEND; end
            end
            S_SEND: begin
                x4_in    <= hold3[dataWidth-1:0];
                x4_valid <= 1'b1;
                hold3    <= hold3 >> dataWidth;
                cnt3     <= cnt3 + 1;
                if (cnt3 == NN3-1) st3 <= S_IDLE;
            end
            default: st3 <= S_IDLE;
        endcase
    end

    // Chup ket qua L4 ngay tai o4_valid
    always @(posedge clk)
        if (o4_valid[0]) l4_result <= x4_out;

    //--------------------------------------------------------------------
    // Task: chay 1 file test (doc file, bom 784 pixel, doi digit_valid)
    //--------------------------------------------------------------------
    task run_one_test;
        input [8*32-1:0] tf;
    begin
        $readmemb(tf, in_mem);
        expected_digit = in_mem[numPixel];   // nhan o dong 785

        for (p = 0; p < numPixel; p = p + 1) begin
            @(posedge clk);
            x1_in    <= in_mem[p];
            x1_valid <= 1'b1;
        end
        @(posedge clk);
        x1_valid <= 1'b0;

        wait (digit_valid == 1'b1);
        @(posedge clk);
    end
    endtask

    //--------------------------------------------------------------------
    initial begin
        if (!$value$plusargs("NUMTESTS=%d", numTests))
            numTests = 10;

        right = 0;
        wrong = 0;
        x1_valid = 1'b0;
        x1_in    = 0;

        reset_n = 1'b0;
        repeat (5) @(posedge clk);
        reset_n = 1'b1;
        repeat (5) @(posedge clk);

        $display("=== BAT DAU BATCH TEST: %0d file ===", numTests);

        for (t = 0; t < numTests; t = t + 1) begin
$sformat(fname, "test_data_%1d%1d%1d%1d.txt",
         (t/1000)%10, (t/100)%10, (t/10)%10, t%10);            
run_one_test(fname);

            if (digit == expected_digit) begin
                right = right + 1;
                $display("%0d. %0s : nhan=%0d, nhan_dien=%0d  OK   | accuracy luy ke: %0.1f%%",
                         t+1, fname, expected_digit, digit, right*100.0/(t+1));
            end
            else begin
                wrong = wrong + 1;
                $display("%0d. %0s : nhan=%0d, nhan_dien=%0d  SAI  | accuracy luy ke: %0.1f%%",
                         t+1, fname, expected_digit, digit, right*100.0/(t+1));
            end

            // nghi vai chu ky giua 2 anh cho pipeline on dinh
            repeat (10) @(posedge clk);
        end

        $display("=================================================================");
        $display(" TONG KET: dung %0d / %0d  =>  ACCURACY = %0.2f%%",
                 right, numTests, right*100.0/numTests);
        $display("=================================================================");
        #100;
        $stop;
    end

    // Watchdog: moi anh mat ~ vai nghin ns; cho du 100 anh
    initial begin
        #100_000_000;
        $display("!!! TIMEOUT toan cuc. Kiem tra file .mif/test_data trong pwd !!!");
        $stop;
    end

endmodule
