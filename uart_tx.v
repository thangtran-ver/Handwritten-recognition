// uart_tx.v
// UART transmitter don gian - khong FIFO, khong APB
// Nhan lenh gui 1 byte, tu dong shift ra chan tx_pin theo dinh dang UART chuan

module uart_tx #(
    parameter CLK_FREQ  = 50000000,
    parameter BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       reset_n,
    input  wire [7:0] tx_data,     // byte can gui
    input  wire       tx_start,    // xung 1 chu ky de bat dau gui
    output reg        tx_pin,      // chan vat ly gui UART
    output reg        tx_busy      // dang gui, chua san sang nhan lenh moi
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    localparam IDLE      = 2'b00;
    localparam START_BIT = 2'b01;
    localparam DATA_BITS = 2'b10;
    localparam STOP_BIT  = 2'b11;

    reg [1:0]  state;
    reg [15:0] clk_count;
    reg [2:0]  bit_index;
    reg [7:0]  tx_shift;

    always @(posedge clk) begin
        if (!reset_n) begin
            state     <= IDLE;
            clk_count <= 0;
            bit_index <= 0;
            tx_pin    <= 1'b1;   // duong truyen ranh (idle) o muc cao
            tx_busy   <= 1'b0;
        end
        else begin
            case (state)
                IDLE: begin
                    tx_pin  <= 1'b1;
                    tx_busy <= 1'b0;
                    if (tx_start) begin
                        tx_shift  <= tx_data;
                        tx_busy   <= 1'b1;
                        clk_count <= 0;
                        state     <= START_BIT;
                    end
                end

                START_BIT: begin
                    tx_pin <= 1'b0;              // start bit = muc thap
                    if (clk_count < CLKS_PER_BIT-1)
                        clk_count <= clk_count + 1;
                    else begin
                        clk_count <= 0;
                        bit_index <= 0;
                        state     <= DATA_BITS;
                    end
                end

                DATA_BITS: begin
                    tx_pin <= tx_shift[bit_index];  // LSB truoc
                    if (clk_count < CLKS_PER_BIT-1)
                        clk_count <= clk_count + 1;
                    else begin
                        clk_count <= 0;
                        if (bit_index < 7)
                            bit_index <= bit_index + 1;
                        else
                            state <= STOP_BIT;
                    end
                end

                STOP_BIT: begin
                    tx_pin <= 1'b1;               // stop bit = muc cao
                    if (clk_count < CLKS_PER_BIT-1)
                        clk_count <= clk_count + 1;
                    else begin
                        clk_count <= 0;
                        tx_busy   <= 1'b0;
                        state     <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
