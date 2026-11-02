`timescale 1ns / 1ps


// ===================================================================
// uart
// ===================================================================

module uart (
    input        clk,
    input        rst,
    // rx
    input        rx,
    input        rx_pop,
    output [7:0] rx_pop_data,
    output       rx_empty,
    // tx
    input        tx_push,
    input  [7:0] tx_push_data,
    output       tx_full,
    output       tx
);
    // baud tick
    wire w_b_tick;
    // rx
    wire [7:0] w_rx_data;
    wire w_rx_done;
    // tx
    wire w_tx_busy;
    wire [7:0] w_fifo_tx_pop_data;
    wire w_fifo_tx_empty;

    uart_rx U_UART_RX (
        .clk    (clk),
        .rst    (rst),
        .b_tick (w_b_tick),
        .rx     (rx),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );

    fifo U_FIFO_RX (
        .clk      (clk),
        .rst      (rst),
        .push     (w_rx_done),
        .pop      (rx_pop),
        .push_data(w_rx_data),
        .pop_data (rx_pop_data),
        .full     (),
        .empty    (rx_empty)
    );

    fifo U_FIFO_TX (
        .clk      (clk),
        .rst      (rst),
        .push     (tx_push),
        .pop      (~w_fifo_tx_empty && ~w_tx_busy),
        .push_data(tx_push_data),
        .pop_data (w_fifo_tx_pop_data),
        .full     (tx_full),
        .empty    (w_fifo_tx_empty)
    );

    uart_tx U_UART_TX (
        .clk     (clk),
        .rst     (rst),
        .b_tick  (w_b_tick),
        .tx_start(~w_fifo_tx_empty && ~w_tx_busy),
        .tx_data (w_fifo_tx_pop_data),
        .tx      (tx),
        .tx_busy (w_tx_busy)
    );

    baud_tick_gen U_TICK_GEN (
        .clk   (clk),
        .rst   (rst),
        .b_tick(w_b_tick)
    );

endmodule

// --=================================================================--


// ===================================================================
// uart_rx
// ===================================================================

module uart_rx (
    input        clk,
    input        rst,
    input        b_tick,
    input        rx,
    output [7:0] rx_data,
    output       rx_done
);
    localparam IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;

    reg [1:0] c_state, n_state;
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    reg [7:0] data_reg, data_next;
    reg rx_done_reg, rx_done_next;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            c_state        <= IDLE;
            b_tick_cnt_reg <= 0;
            bit_cnt_reg    <= 0;
            data_reg       <= 0;
            rx_done_reg    <= 0;
        end else begin
            c_state        <= n_state;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            data_reg       <= data_next;
            rx_done_reg    <= rx_done_next;
        end
    end

    always @(*) begin
        n_state = c_state;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next = bit_cnt_reg;
        data_next = data_reg;
        rx_done_next = rx_done_reg;

        case(c_state)
            IDLE: begin
                if(b_tick) begin
                    if(!rx) begin
                        n_state = START;
                        b_tick_cnt_next = 0;
                    end
                end
                rx_done_next = 0;
            end
            START: begin
                if(b_tick) begin
                    if(b_tick_cnt_reg == 4'd7) begin
                        n_state = DATA;
                        b_tick_cnt_next = 0;
                        bit_cnt_next = 0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end

            end
            DATA: begin
                if(b_tick) begin
                    if(b_tick_cnt_reg == 4'd15) begin
                        b_tick_cnt_next = 0;
                        data_next = {rx, data_reg[7:1]};
                        if(bit_cnt_reg == 3'd7) begin
                            n_state = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                if(b_tick) begin
                    if(b_tick_cnt_reg == 4'd15) begin
                        n_state = IDLE;
                        rx_done_next = 1'b1;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end

    assign rx_data = data_reg;
    assign rx_done = rx_done_reg;

endmodule

// --=================================================================--


// ===================================================================
// uart_tx
// ===================================================================

module uart_tx (
    input        clk,
    input        rst,
    input        b_tick,
    input        tx_start,
    input  [7:0] tx_data,
    output       tx,
    output       tx_busy
);

    localparam IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;

    // state signals
    reg [1:0] c_state, n_state;
    // output signals
    reg tx_reg, tx_next;
    reg tx_busy_reg, tx_busy_next;
    // 
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    reg [7:0] data_reg, data_next;

    // c_state
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            c_state        <= 0;
            tx_reg         <= 1;    // default : 1
            tx_busy_reg    <= 0;
            b_tick_cnt_reg <= 0;
            bit_cnt_reg    <= 0;
            data_reg       <= 0;
        end else begin
            c_state        <= n_state;
            tx_reg         <= tx_next;
            tx_busy_reg    <= tx_busy_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            data_reg       <= data_next;
        end
    end

    // n_state, output
    always @(*) begin
        n_state         = c_state;
        tx_next         = tx_reg;
        tx_busy_next    = tx_busy_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;
        data_next       = data_reg;
        case(c_state)
            IDLE: begin
                if(tx_start) begin
                    n_state = START;
                    data_next = tx_data;
                    tx_busy_next = 1'b1;
                end 
            end
            START: begin
                if(b_tick) begin
                    if(!tx_reg) begin
                        if(b_tick_cnt_reg == 4'd15) begin
                            n_state = DATA;
                            b_tick_cnt_next = 0;
                            bit_cnt_next = 0;
                            data_next = data_reg >> 1;
                            tx_next = data_reg[0];
                        end else begin
                            b_tick_cnt_next = b_tick_cnt_reg + 1;
                        end
                    end else begin
                        b_tick_cnt_next = 0;
                        tx_next = 0;
                    end
                end
            end
            DATA: begin
                if(b_tick) begin
                    if(b_tick_cnt_reg == 4'd15) begin
                        b_tick_cnt_next = 0;
                        if(bit_cnt_reg == 3'd7) begin
                            n_state = STOP;
                            tx_next = 1'b1;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                            data_next = data_reg >> 1;
                            tx_next = data_reg[0];
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                if(b_tick) begin
                    if(b_tick_cnt_reg == 4'd15) begin
                        n_state = IDLE;
                        tx_busy_next = 0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end

    assign tx = tx_reg;
    assign tx_busy = tx_busy_reg;

endmodule

// --=================================================================--


// ===================================================================
// baud_tick_gen
// ===================================================================

module baud_tick_gen (
    input      clk,
    input      rst,
    output reg b_tick
);
    parameter F_COUNT = 100_000_000 / (9600 * 16);
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            b_tick <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            b_tick <= 1'b0;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                b_tick <= 1'b1;
            end
        end
    end

endmodule

// --=================================================================--


// ===================================================================
// fifo
// ===================================================================

module fifo #(
    parameter DEPTH = 4,
    A_BIT_WIDTH = $clog2(DEPTH),
    D_BIT_WIDTH = 8
) (
    input        clk,
    input        rst,
    input        push,
    input        pop,
    input  [7:0] push_data,
    output [7:0] pop_data,
    output       full,
    output       empty
);

    wire [A_BIT_WIDTH-1:0] w_wptr, w_rptr;

    register_file #(
        .DEPTH(DEPTH),
        .D_BIT_WIDTH(D_BIT_WIDTH)
    ) U_REGISTER_FILE (
        .clk  (clk),
        .we   (~full & push),
        .waddr(w_wptr),
        .raddr(w_rptr),
        .wdata(push_data),
        .rdata(pop_data)
    );

    control_unit #(
        .A_BIT_WIDTH(A_BIT_WIDTH)
    ) U_CONTROL_UNIT (
        .clk  (clk),
        .rst  (rst),
        .push (push),
        .pop  (pop),
        .wptr (w_wptr),
        .rptr (w_rptr),
        .full (full),
        .empty(empty)
    );

endmodule

// --=================================================================--


// ===================================================================
// control_unit
// ===================================================================

module control_unit #(
    parameter A_BIT_WIDTH = 2
) (
    input                    clk,
    input                    rst,
    input                    push,
    input                    pop,
    output [A_BIT_WIDTH-1:0] wptr,
    output [A_BIT_WIDTH-1:0] rptr,
    output                   full,
    output                   empty
);

    // Sequential Logic
    reg [A_BIT_WIDTH-1:0] wptr_reg, wptr_next;
    reg [A_BIT_WIDTH-1:0] rptr_reg, rptr_next;

    reg full_reg, full_next;
    reg empty_reg, empty_next;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wptr_reg  <= 0;
            rptr_reg  <= 0;
            full_reg  <= 1'b0;
            empty_reg <= 1'b1;
        end else begin
            wptr_reg  <= wptr_next;
            rptr_reg  <= rptr_next;
            full_reg  <= full_next;
            empty_reg <= empty_next;
        end
    end

    always @(*) begin
        wptr_next  = wptr_reg;
        rptr_next  = rptr_reg;
        full_next  = full_reg;
        empty_next = empty_reg;

        case ({
            push, pop
        })
            2'b01: begin  // pop only
                if (!empty_reg) begin
                    full_next = 1'b0;
                    rptr_next = rptr_reg + 1;
                    if (rptr_next == wptr_reg) begin
                        empty_next = 1'b1;
                    end
                end
            end
            2'b10: begin  // push only
                if (!full_reg) begin
                    empty_next = 1'b0;
                    wptr_next  = wptr_reg + 1;
                    if (wptr_next == rptr_reg) begin
                        full_next = 1'b1;
                    end
                end
            end
            2'b11: begin  // push & pop
                if (full_reg == 1'b1) begin
                    full_next = 1'b0;
                    rptr_next = rptr_reg + 1;
                end else if (empty == 1) begin
                    empty_next = 1'b0;
                    wptr_next  = wptr_reg + 1;
                end else begin
                    wptr_next = wptr_reg + 1;
                    rptr_next = rptr_reg + 1;
                end
            end
        endcase
    end

    assign wptr  = wptr_reg;
    assign rptr  = rptr_reg;
    assign full  = full_reg;
    assign empty = empty_reg;

endmodule

// --=================================================================--


// ===================================================================
// register_file
// ===================================================================

module register_file #(
    parameter DEPTH = 4,
    A_BIT_WIDTH = $clog2(DEPTH),
    D_BIT_WIDTH = 8
) (
    input                    clk,
    input                    we,
    input  [A_BIT_WIDTH-1:0] waddr,
    input  [A_BIT_WIDTH-1:0] raddr,
    input  [D_BIT_WIDTH-1:0] wdata,
    output [D_BIT_WIDTH-1:0] rdata
);

    reg [D_BIT_WIDTH-1:0] register_file[0:DEPTH-1];

    // write SL
    always @(posedge clk) begin
        if (we) register_file[waddr] <= wdata;
    end

    // read CL
    assign rdata = register_file[raddr];

endmodule

// --=================================================================--
