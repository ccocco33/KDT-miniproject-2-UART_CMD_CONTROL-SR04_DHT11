`timescale 1ns / 1ps


// ===================================================================
// sr04_top
// ===================================================================

module sr04_top (
    input        clk,
    input        rst,
    input        en,
    input        sr04_start,
    input        echo,
    output       trigger,
    output [7:0] distance_low,
    output [7:0] distance_high,
    output       sr04_busy,
    output       sr04_done
);

    //==================================================================
    // 1. Wire Declaration
    //==================================================================

    wire w_us_tick;

    wire w_us_tick_enable;
    wire w_us_tick_clear;


    //==================================================================
    // 2. Micro-Second Tick Generator
    //==================================================================

    us_tick_gen u_US_TICK_GEN (
        .clk           (clk),
        .rst           (rst),
        .en            (en),
        .us_tick_enable(w_us_tick_enable),
        .us_tick_clear (w_us_tick_clear),
        .o_tick        (w_us_tick)
    );


    //==================================================================
    // 3. Echo Synchronizer
    //==================================================================

    reg  sync_ff1;
    reg  sync_ff2;
    wire w_echo_sync;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sync_ff1 <= 1'b0;
            sync_ff2 <= 1'b0;
        end else if (en) begin
            sync_ff1 <= echo;
            sync_ff2 <= sync_ff1;
        end
    end

    assign w_echo_sync = sync_ff2;


    //==================================================================
    // 4. SR04 Controller
    //==================================================================

    sr04_control u_SR04_CONTROL (
        .clk           (clk),
        .rst           (rst),
        .sr04_start    (sr04_start),
        .us_tick       (w_us_tick),
        .echo          (w_echo_sync),
        .us_tick_enable(w_us_tick_enable),
        .us_tick_clear (w_us_tick_clear),
        .trigger       (trigger),
        .distance_low  (distance_low),
        .distance_high (distance_high),
        .sr04_busy     (sr04_busy),
        .sr04_done     (sr04_done)
    );


endmodule

// --=================================================================--


// ===================================================================
// sr04_control
// ===================================================================

module sr04_control (
    input            clk,
    input            rst,
    input            sr04_start,
    input            us_tick,
    input            echo,
    output reg       us_tick_enable,
    output           us_tick_clear,
    output reg       sr04_busy,
    output           trigger,
    output     [7:0] distance_high,   // hundreds (0~4)
    output     [7:0] distance_low,    // 0~99
    output           sr04_done
);
    parameter IDLE = 3'b000, START = 3'b001, WAIT = 3'b010, DISTANCE = 3'b011, STOP = 3'b100;

    reg [2:0] c_state, n_state;
    reg [15:0] count_reg, count_next;
    reg trigger_reg, trigger_next;

    // 58us = 1cm, start at 29 for rounding
    reg [5:0] cnt58_reg, cnt58_next;

    // distance counter (counting)
    reg [6:0] cm_low_reg, cm_low_next;  // 0~99
    reg [2:0] cm_high_reg, cm_high_next;  // 0~4

    // distance result (latched)
    reg [6:0] distance_low_reg, distance_low_next;
    reg [2:0] distance_high_reg, distance_high_next;

    reg sr04_done_reg, sr04_done_next;

    assign us_tick_clear = sr04_start;
    assign trigger = trigger_reg;
    assign distance_low = {1'b0, distance_low_reg};
    assign distance_high = {5'b0, distance_high_reg};
    assign sr04_done = sr04_done_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            c_state           <= IDLE;
            count_reg         <= 16'd0;
            trigger_reg       <= 1'b0;
            cnt58_reg         <= 6'd0;
            cm_low_reg        <= 7'd0;
            cm_high_reg       <= 3'd0;
            distance_low_reg  <= 7'd0;
            distance_high_reg <= 3'd0;
            sr04_done_reg     <= 1'b0;
        end else begin
            c_state           <= n_state;
            count_reg         <= count_next;
            trigger_reg       <= trigger_next;
            cnt58_reg         <= cnt58_next;
            cm_low_reg        <= cm_low_next;
            cm_high_reg       <= cm_high_next;
            distance_low_reg  <= distance_low_next;
            distance_high_reg <= distance_high_next;
            sr04_done_reg     <= sr04_done_next;
        end
    end

    always @(*) begin
        n_state = c_state;

        count_next = count_reg;
        trigger_next = trigger_reg;
        cnt58_next = cnt58_reg;
        cm_low_next = cm_low_reg;
        cm_high_next = cm_high_reg;
        distance_low_next = distance_low_reg;
        distance_high_next = distance_high_reg;
        sr04_done_next = sr04_done_reg;

        us_tick_enable = 1'b0;
        sr04_busy = 1'b0;

        case (c_state)
            IDLE: begin
                if (sr04_start) begin
                    n_state = START;
                    count_next = 0;
                    trigger_next = 1'b1;
                end
                sr04_done_next = 1'b0;
            end
            START: begin
                if (us_tick) begin
                    if (count_reg >= 16'd10) begin
                        n_state = WAIT;
                        trigger_next = 1'b0;
                    end else begin
                        count_next = count_reg + 1;
                    end
                end
                us_tick_enable = 1'b1;
                sr04_busy = 1'b1;
            end
            WAIT: begin
                if (us_tick) begin
                    if (echo) begin
                        n_state = DISTANCE;
                        count_next = 0;
                        cnt58_next = 6'd29;
                        cm_low_next = 7'd0;
                        cm_high_next = 3'd0;
                    end
                end
                us_tick_enable = 1'b1;
                sr04_busy = 1'b1;
            end
            DISTANCE: begin
                if (us_tick) begin
                    // echo end or 400cm timeout
                    if ((echo == 1'b0) || (cm_high_reg == 3'd4)) begin
                        n_state = STOP;
                        count_next = 0;
                        distance_low_next = cm_low_reg;
                        distance_high_next = cm_high_reg;
                    end else begin
                        if (cnt58_reg == 6'd57) begin
                            cnt58_next = 0;
                            if (cm_low_reg == 7'd99) begin
                                cm_low_next  = 0;
                                cm_high_next = cm_high_reg + 1;
                            end else begin
                                cm_low_next = cm_low_reg + 1;
                            end
                        end else begin
                            cnt58_next = cnt58_reg + 1;
                        end
                    end
                end
                us_tick_enable = 1'b1;
                sr04_busy = 1'b1;
            end
            STOP: begin
                if (us_tick) begin
                    if (count_reg >= 10000 - 1) begin
                        n_state = IDLE;
                        sr04_done_next = 1'b1;
                    end else begin
                        count_next = count_reg + 1;
                    end
                end
                us_tick_enable = 1'b1;
                sr04_busy = 1'b1;
            end
        endcase
    end
endmodule

// --=================================================================--


// ===================================================================
// dht11_top
// ===================================================================

module dht11_top (
    input             clk,
    input             rst,
    input             en,
    input             dht11_start,

    inout             dht11_io,

    output            dht11_valid,
    output     [15:0] humidity,
    output     [15:0] temperature,
    output            dht11_busy,
    output            dht11_done
);

    //==================================================================
    // 1. Wire Declaration
    //==================================================================

    wire w_us_tick_enable;
    wire w_us_tick_clear;
    wire w_us_tick;


    //==================================================================
    // 2. Micro-Second Tick Generator
    //==================================================================

    us_tick_gen u_US_TICK_GEN (
        .clk            (clk),
        .rst            (rst),
        .en             (en),
        .us_tick_enable (w_us_tick_enable),
        .us_tick_clear  (w_us_tick_clear),
        .o_tick         (w_us_tick)
    );


    //==================================================================
    // 3. DHT11 Controller
    //==================================================================

    dht11_control u_DHT11_CONTROL (
        .clk            (clk),
        .rst            (rst),
        .en             (en),
        .dht11_start    (dht11_start),
        .us_tick        (w_us_tick),

        .dht11_io       (dht11_io),

        .us_tick_enable (w_us_tick_enable),
        .us_tick_clear  (w_us_tick_clear),
        .dht11_valid    (dht11_valid),
        .humidity       (humidity),
        .temperature    (temperature),
        .dht11_busy     (dht11_busy),
        .dht11_done     (dht11_done)
    );


endmodule

// --=================================================================--


// ===================================================================
// dht11_control
// ===================================================================

// --=================================================================--
// (C) COPYRIGHT 2026
//     All Right Reserved
//
//
//
//
// ---------------------------------------------------------------------
// File Name   : dht11_control.v
// Module Name : dht11_control
// Date        : 10/30/2026
// Author      : Changmin Oh
// ---------------------------------------------------------------------
// Purpose     :
// ---------------------------------------------------------------------
// Revision History
// @
// --=================================================================--


module dht11_control (
    input              clk,
    input              rst,
    input              en,
    input              dht11_start,
    input              us_tick,

    inout              dht11_io,

    output             us_tick_enable,
    output             us_tick_clear,
    output             dht11_valid,
    output      [15:0] humidity,
    output      [15:0] temperature,
    output             dht11_busy,
    output             dht11_done
);

    //==================================================================
    // 1. FSM State
    //==================================================================

    localparam IDLE      = 3'd0;
    localparam START     = 3'd1;
    localparam WAIT      = 3'd2;
    localparam SYNC_LOW  = 3'd3;
    localparam SYNC_HIGH = 3'd4;
    localparam DATA_SYNC = 3'd5;
    localparam BIT_COUNT = 3'd6;
    localparam STOP      = 3'd7;


    //==================================================================
    // 2. Register Declaration
    //==================================================================

    // State Register
    reg   [2:0] c_state, n_state;

    // DHT11 I/O Control
    reg         dht11_io_control_reg;
    reg         dht11_io_control_next;

    // Input Synchronizer
    reg         dht11_sync1;
    reg         dht11_sync2;

    // Status Flags
    reg         valid_reg,       valid_next;
    reg         busy_reg,        busy_next;
    reg         done_reg,        done_next;

    // Output Registers
    reg  [15:0] humidity_reg,    humidity_next;
    reg  [15:0] temperature_reg, temperature_next;

    // Data Shift Register
    reg  [39:0] data_reg,        data_next;

    // Counter Registers
    reg  [14:0] us_tick_cnt_reg, us_tick_cnt_next;
    reg   [5:0] bit_cnt_reg,     bit_cnt_next;


    //==================================================================
    // 3. Open Drain I/O Control
    //==================================================================

    // 1 : Drive LOW
    // 0 : High Impedance

    assign dht11_io = (dht11_io_control_reg) ? 1'b0 : 1'bz;


    //==================================================================
    // 4. Output Assignment
    //==================================================================

    assign humidity       = humidity_reg;
    assign temperature    = temperature_reg;

    assign dht11_valid    = valid_reg;
    assign dht11_busy     = busy_reg;
    assign dht11_done     = done_reg;

    assign us_tick_enable = (c_state != IDLE);
    assign us_tick_clear  = (c_state == IDLE);


    //==================================================================
    // 5. Input Synchronizer
    //==================================================================

    always @(posedge clk or posedge rst) begin

        if (rst) begin
            dht11_sync1 <= 1'b1;
            dht11_sync2 <= 1'b1;
        end

        else if (en) begin
            dht11_sync1 <= dht11_io;
            dht11_sync2 <= dht11_sync1;
        end
    end


    //==================================================================
    // 6. Sequential Logic
    //==================================================================

    always @(posedge clk or posedge rst) begin

        if (rst) begin
            c_state              <= IDLE;

            dht11_io_control_reg <= 1'b0;

            us_tick_cnt_reg      <= 15'd0;
            bit_cnt_reg          <= 6'd0;

            valid_reg            <= 1'b0;
            busy_reg             <= 1'b0;
            done_reg             <= 1'b0;

            humidity_reg         <= 16'd0;
            temperature_reg      <= 16'd0;

            data_reg             <= 40'd0;
        end

        else if (en) begin
            c_state              <= n_state;

            dht11_io_control_reg <= dht11_io_control_next;

            us_tick_cnt_reg      <= us_tick_cnt_next;
            bit_cnt_reg          <= bit_cnt_next;

            valid_reg            <= valid_next;
            busy_reg             <= busy_next;
            done_reg             <= done_next;

            humidity_reg         <= humidity_next;
            temperature_reg      <= temperature_next;

            data_reg             <= data_next;
        end
    end


    //==================================================================
    // 7. Next State and Output Logic
    //==================================================================

    always @(*) begin

        // Default Assignment
	
        n_state               = c_state;

        dht11_io_control_next = dht11_io_control_reg;

        us_tick_cnt_next      = us_tick_cnt_reg;
        bit_cnt_next          = bit_cnt_reg;

        valid_next            = valid_reg;
        busy_next             = busy_reg;
        done_next             = done_reg;

        humidity_next         = humidity_reg;
        temperature_next      = temperature_reg;

        data_next             = data_reg;


        case (c_state)

            //==========================================================
            // IDLE
            //==========================================================

            IDLE: begin

                // Release DATA Line
                dht11_io_control_next = 1'b0;

                bit_cnt_next          = 6'd0;

                busy_next             = 1'b0;

                if (dht11_start) begin
                    n_state          = START;

                    us_tick_cnt_next = 15'd0;

                    valid_next       = 1'b0;
                    busy_next        = 1'b1;
                    done_next        = 1'b0;

                    data_next        = 40'd0;
                end
            end


            //==========================================================
            // START
            //==========================================================

            START: begin

                // Drive DATA LOW
                dht11_io_control_next = 1'b1;

                if (us_tick) begin

                    if (us_tick_cnt_reg >= 20_000 - 1) begin
                        n_state          = WAIT;

                        us_tick_cnt_next = 15'd0;
                    end

                    else begin
                        us_tick_cnt_next = us_tick_cnt_reg + 1'b1;
                    end
                end
            end


            //==========================================================
            // WAIT
            //==========================================================

            WAIT: begin

                // Release DATA Line
                dht11_io_control_next = 1'b0;

                if (us_tick) begin

                    // Sensor Response LOW Detection
                    if (!dht11_sync2) begin
                        n_state          = SYNC_LOW;

                        us_tick_cnt_next = 15'd0;
                    end

                    // Response Timeout
                    else if (us_tick_cnt_reg >= 100 - 1) begin
                        n_state          = STOP;

                        us_tick_cnt_next = 15'd0;

                        valid_next       = 1'b0;
                    end

                    else begin
                        us_tick_cnt_next = us_tick_cnt_reg + 1'b1;
                    end
                end
            end


            //==========================================================
            // SYNC_LOW
            //==========================================================

            SYNC_LOW: begin

                if (us_tick) begin

                    // LOW -> HIGH
                    if (dht11_sync2) begin
                        n_state          = SYNC_HIGH;

                        us_tick_cnt_next = 15'd0;
                    end

                    // Timeout
                    else if (us_tick_cnt_reg >= 100 - 1) begin
                        n_state          = STOP;

                        us_tick_cnt_next = 15'd0;

                        valid_next       = 1'b0;
                    end

                    else begin
                        us_tick_cnt_next = us_tick_cnt_reg + 1'b1;
                    end
                end
            end


            //==========================================================
            // SYNC_HIGH
            //==========================================================

            SYNC_HIGH: begin

                if (us_tick) begin

                    // HIGH -> LOW
                    if (!dht11_sync2) begin
                        n_state          = DATA_SYNC;

                        us_tick_cnt_next = 15'd0;
                    end

                    // Timeout
                    else if (us_tick_cnt_reg >= 100 - 1) begin
                        n_state          = STOP;

                        us_tick_cnt_next = 15'd0;

                        valid_next       = 1'b0;
                    end

                    else begin
                        us_tick_cnt_next = us_tick_cnt_reg + 1'b1;
                    end
                end
            end


            //==========================================================
            // DATA_SYNC
            //==========================================================

            DATA_SYNC: begin

                if (us_tick) begin

                    // LOW -> HIGH
                    // Start of Data HIGH Pulse

                    if (dht11_sync2) begin
                        n_state          = BIT_COUNT;

                        us_tick_cnt_next = 15'd0;
                    end

                    // Timeout
                    else if (us_tick_cnt_reg >= 100 - 1) begin
                        n_state          = STOP;

                        us_tick_cnt_next = 15'd0;

                        valid_next       = 1'b0;
                    end

                    else begin
                        us_tick_cnt_next = us_tick_cnt_reg + 1'b1;
                    end
                end
            end

            //==========================================================
            // BIT_COUNT
            //==========================================================

            BIT_COUNT: begin

                if (us_tick) begin

                    // HIGH -> LOW
                    // End of Data HIGH Pulse

                    if (!dht11_sync2) begin

                        // Data Sampling
                        data_next = {
                            data_reg[38:0],
                            (us_tick_cnt_reg >= 40)
                        };

                        us_tick_cnt_next = 15'd0;


                        // Last Bit Detection
                        if (bit_cnt_reg == 40 - 1) begin
                            n_state      = STOP;

                            bit_cnt_next = 6'd0;

                            // Checksum Verification (Using data_next)
                            if (data_next[7:0] == 
				               (data_next[39:32] + 
				                data_next[31:24] + 
				                data_next[23:16] + 
				                data_next[15:8])
			                    ) begin

                                valid_next = 1'b1;

                                humidity_next =
                                    data_next[39:24];

                                temperature_next =
                                    data_next[23:8];

                            end

                            else begin
                                valid_next = 1'b0;
                            end
                        end

                        else begin
                            n_state = DATA_SYNC;

                            bit_cnt_next = bit_cnt_reg + 1'b1;
                        end
                    end


                    // HIGH Pulse Timeout
                    else if (us_tick_cnt_reg >= 100 - 1) begin
                        n_state          = STOP;

                        us_tick_cnt_next = 15'd0;

                        valid_next       = 1'b0;
                    end

                    else begin
                        us_tick_cnt_next = us_tick_cnt_reg + 1'b1;
                    end
                end
            end

            //==========================================================
            // STOP
            //==========================================================

            STOP: begin

                // Release DATA Line
                dht11_io_control_next = 1'b0;

                if (us_tick) begin

                    if (us_tick_cnt_reg >= 60 - 1) begin
                        n_state          = IDLE;

                        us_tick_cnt_next = 15'd0;

                        busy_next        = 1'b0;
                        done_next        = 1'b1;
		    end

                    else begin
                        us_tick_cnt_next = us_tick_cnt_reg + 1'b1;
                    end
                end
            end


            //==========================================================
            // DEFAULT
            //==========================================================

            default: begin
                n_state               = IDLE;

                dht11_io_control_next = 1'b0;

                us_tick_cnt_next      = 15'd0;
                bit_cnt_next          = 6'd0;

                valid_next            = 1'b0;
                busy_next             = 1'b0;
                done_next             = 1'b0;

                humidity_next         = 16'd0;
                temperature_next      = 16'd0;

                data_next             = 40'd0;
            end
        endcase
    end

endmodule

// --=================================================================--


// ===================================================================
// us_tick_gen
// ===================================================================

module us_tick_gen (
    input         clk,
    input         rst,
    input         en,
    input         us_tick_enable,
    input         us_tick_clear,
    output        o_tick
);

    // Division Parameters (100MHz / 1MHz = 100)
    localparam integer DIV   = (100_000_000 / 1_000_000);
    localparam integer CNT_W = $clog2(DIV);

    // Count Register
    reg  [CNT_W-1:0] c_count;
    wire [CNT_W-1:0] n_count;

    // Max Count Flag
    wire count_max;
    assign count_max = (c_count == DIV - 1);

    // Counter Sequential Logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            c_count <= {CNT_W{1'b0}};
        end
        else if (en) begin
            if (us_tick_clear) begin
                c_count <= {CNT_W{1'b0}};
            end
            else if (us_tick_enable) begin
                c_count <= n_count;
            end
        end
    end

    // Next Count Assignment
    assign n_count = (count_max) ? {CNT_W{1'b0}} : c_count + 1'b1;

    // Baud Tick Assignment
    assign o_tick  = (count_max) && (en) && (us_tick_enable);

endmodule

// --=================================================================--
