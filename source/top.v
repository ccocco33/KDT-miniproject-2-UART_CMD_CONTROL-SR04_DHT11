`timescale 1ns / 1ps


// ===================================================================
// uart_fifo_ascii
// ===================================================================

module uart_fifo_ascii (
    input             clk,
    input             rst,

    input             rx,

    input             sw0,
    input             sw1,
    input             sw2,
    input             sw3,

    input             btnR,
    input             btnL,
    input             btnD,
    input             btnU,

    input             sr04_echo,

    inout             dht11_io,
    
    output            sr04_trigger,

    output            tx,

    output      [3:0] fnd_com,
    output      [7:0] fnd_font
);

    //==================================================================
    // 1. Internal Wires
    //==================================================================

    wire w_btnR, w_btnL, w_btnD, w_btnU;

    wire  [7:0] w_rx_pop_data;
    wire        w_rx_empty;
    wire        w_rx_pop;

    wire        w_tx_full;
    wire        w_tx_push;
    wire  [7:0] w_tx_push_data;

    // Mode Selection
    wire  [1:0] w_sw_show_mode;

    // stopwatch
    wire        w_stopwatch_btnR;
    wire        w_stopwatch_btnL;
    wire        w_stopwatch_btnD;
    wire        w_stopwatch_btnU;

    // watch
    wire  [1:0] w_selected_digit;
    wire        w_watch_btnR;
    wire        w_watch_btnL;
    wire        w_watch_btnD;
    wire        w_watch_btnU;

    // SR04
    wire        w_sr04_start;
    wire        w_sr04_busy;
    wire        w_sr04_done;

    // dht11
    wire        w_dht11_start;
    wire        w_dht11_valid;
    wire        w_dht11_busy;
    wire        w_dht11_done;

    // Datapath Output
    wire [31:0] w_stopwatch;
    wire [31:0] w_watch;
    wire [31:0] w_sr04;
    wire [31:0] w_dht11;
    wire [31:0] w_mux_out;


    //==================================================================
    // 2. Button Debouncer
    //==================================================================

    btn_debounce u_BTNR (
        .clk   (clk),
        .rst   (rst),
        .i_btn (btnR),
        .o_btn (w_btnR)
    );

    btn_debounce u_BTNL (
        .clk   (clk),
        .rst   (rst),
        .i_btn (btnL),
        .o_btn (w_btnL)
    );

    btn_debounce u_BTND (
        .clk   (clk),
        .rst   (rst),
        .i_btn (btnD),
        .o_btn (w_btnD)
    );

    btn_debounce u_BTNU (
        .clk   (clk),
        .rst   (rst),
        .i_btn (btnU),
        .o_btn (w_btnU)
    );


    //==================================================================
    // 3. Mode Selection Assignment
    //==================================================================

    assign w_sw_show_mode = {sw1, sw0};


    //==================================================================
    // 4. UART
    //==================================================================

    uart u_UART (
        .clk          (clk),
        .rst          (rst),
        // rx        
        .rx           (rx),
        .rx_pop       (w_rx_pop),
        .rx_pop_data  (w_rx_pop_data),
        .rx_empty     (w_rx_empty),
        // tx        
        .tx_push      (w_tx_push),
        .tx_push_data (w_tx_push_data),
        .tx_full      (w_tx_full),
        .tx           (tx)
    );


    //==================================================================
    // 5. Control Unit
    //==================================================================

    cmd_control_unit u_CMD_CONTROL_UNIT (
        .clk             (clk),
        .rst             (rst),

        // UA
        .rx_pop_data     (w_rx_pop_data),
        .rx_empty        (w_rx_empty),
        .rx_pop          (w_rx_pop),

        // UA
        .tx_full         (w_tx_full),
        .tx_push         (w_tx_push),
        .tx_push_data    (w_tx_push_data),

        // da
        .sw0             (sw0),
        .sw1             (sw1),               // 00 ST, 01 WT, 10 SR04, 11 DHT11
        .display_data    (w_mux_out),         // from datapath mux 32bit

        .btnR            (w_btnR),            // debounced btn_tick
        .btnL            (w_btnL),
        .btnD            (w_btnD),
        .btnU            (w_btnU),

        // stopwatch
        .stopwatch_btnR (w_stopwatch_btnR),
        .stopwatch_btnL (w_stopwatch_btnL),
        .stopwatch_btnD (w_stopwatch_btnD),
        .stopwatch_btnU (w_stopwatch_btnU),

        // watch
        .watch_btnR     (w_watch_btnR),
        .watch_btnL     (w_watch_btnL),
        .watch_btnD     (w_watch_btnD),
        .watch_btnU     (w_watch_btnU),

        // SR04
        .sr04_busy      (w_sr04_busy),
        .sr04_start     (w_sr04_start),

        // dht11
        .dht11_busy     (w_dht11_busy),
        .dht11_start    (w_dht11_start)
    );


    //==================================================================
    // 6. Datapath
    //==================================================================

    datapath u_DATAPATH (
        // Sequential Elements
        .clk             (clk),
        .rst             (rst),

        // Stopwatch buttons
        .stopwatch_btnR  (w_stopwatch_btnR),
        .stopwatch_btnL  (w_stopwatch_btnL),
        .stopwatch_btnU  (w_stopwatch_btnU),
        .stopwatch_btnD  (w_stopwatch_btnD),

        // Watch buttons
        .watch_btnR      (w_watch_btnR),
        .watch_btnL      (w_watch_btnL),
        .watch_btnU      (w_watch_btnU),
        .watch_btnD      (w_watch_btnD),

        // Watch Mode 
        // .sw_show_mode    (w_sw_show_mode),
        .sw_display_mode (sw2),
        .sw_time_edit    (sw3),

        // Sensor Control
        // SR04 Control
        .sr04_start      (w_sr04_start),
        .sr04_busy       (w_sr04_busy),
        .sr04_done       (w_sr04_done),
        // DHT11 Control
        .dht11_start     (w_dht11_start),
        .dht11_valid     (w_dht11_valid),
        .dht11_busy      (w_dht11_busy),
        .dht11_done      (w_dht11_done),

        // Sensor interface
        // SR04 Interface
        .sr04_trigger    (sr04_trigger),
        .sr04_echo       (sr04_echo),
        // DHT11 Interface
        .dht11_io         (dht11_io),

        // Datapath Output
        .o_stopwatch     (w_stopwatch),
        .o_watch         (w_watch),
        .o_sr04          (w_sr04),
        .o_dht11         (w_dht11),
        .selected_digit  (w_selected_digit)
    );


    //==================================================================
    // 9. Mux 4x1 Selection
    //==================================================================

    // sw_show_mode
    // 00: watch, 01: stopwatch
    // 10: sr04,  11: dht11
    mux_4x1 u_MUX_4x1 (
        .sel     (w_sw_show_mode),
        .in0     (w_watch),
        .in1     (w_stopwatch),
        .in2     (w_sr04),
        .in3     (w_dht11),
        .mux_out (w_mux_out)
    );


    //==================================================================
    // 10. Flexible Numeric Display
    //==================================================================

    fnd_controller u_FND_CONTROLLER (
        .clk            (clk),
        .rst            (rst),
        // switch
        .sw0            (sw0),  // data show mode switch 0
        .sw1            (sw1),  // data show mode switch 1
        .sw2            (sw2),  // data upper/lower switch
        .sw3            (sw3),  // watch edit switch
        // value
        .value0         (w_mux_out[7:0]),     // must under 100
        .value1         (w_mux_out[15:8]),     // must under 100
        .value2         (w_mux_out[23:16]),     // must under 100
        .value3         (w_mux_out[31:24]),     // must under 100
        // digit select
        .selected_digit (w_selected_digit), //
        // fnd
        .fnd_com        (fnd_com),
        .fnd_font       (fnd_font)
    );


endmodule

// --=================================================================--


// ===================================================================
// datapath
// ===================================================================

module datapath (
    // Sequential Elements
    input clk,
    input rst,

    // Stopwatch buttons
    input stopwatch_btnR,
    input stopwatch_btnL,
    input stopwatch_btnU,
    input stopwatch_btnD,

    // Watch buttons
    input watch_btnR,
    input watch_btnL,
    input watch_btnU,
    input watch_btnD,

    // Watch Mode 
    // input       [1:0] sw_show_mode,
    input sw_display_mode,
    input sw_time_edit,

    // Sensor Control
    // SR04 Control
    input  sr04_start,
    output sr04_busy,
    output sr04_done,
    // DHT11 Control
    input  dht11_start,
    output dht11_valid,
    output dht11_busy,
    output dht11_done,

    // Sensor interface
    // SR04 Interface
    output sr04_trigger,
    input  sr04_echo,
    // DHT11 Interface
    inout  dht11_io,

    // Datapath Output
    output [31:0] o_stopwatch,
    output [31:0] o_watch,
    output [31:0] o_sr04,
    output [31:0] o_dht11,

    // Watch Selected Digit
    output [1:0] selected_digit
);

    //==================================================================
    // 1. Wire Declaration
    //==================================================================

    // Stopwatch
    wire [ 6:0] w_msec_stopwatch;
    wire [ 5:0] w_sec_stopwatch;
    wire [ 5:0] w_min_stopwatch;
    wire [ 4:0] w_hour_stopwatch;

    // Watch
    wire [ 6:0] w_msec_watch;
    wire [ 5:0] w_sec_watch;
    wire [ 5:0] w_min_watch;
    wire [ 4:0] w_hour_watch;

    // SR04
    wire [ 7:0] w_distance_low;
    wire [ 7:0] w_distance_high;

    // DHT11
    wire [15:0] w_humidity;
    wire [15:0] w_temperature;


    //==================================================================
    // 2. Stopwatch Top
    //==================================================================

    stopwatch_top u_STOPWATCH_TOP (
        .clk           (clk),
        .rst           (rst),
        .btnR          (stopwatch_btnR),
        .btnL          (stopwatch_btnL),
        .btnU          (stopwatch_btnU),
        .btnD          (stopwatch_btnD),
        .msec_stopwatch(w_msec_stopwatch),
        .sec_stopwatch (w_sec_stopwatch),
        .min_stopwatch (w_min_stopwatch),
        .hour_stopwatch(w_hour_stopwatch)
    );


    //==================================================================
    // 3. Watch Top
    //==================================================================

    watch_top u_WATCH_TOP (
        .clk            (clk),
        .rst            (rst),
        .btnR           (watch_btnR),
        .btnL           (watch_btnL),
        .btnU           (watch_btnU),
        .btnD           (watch_btnD),
        // .sw_show_mode    (sw_show_mode),
        .sw_display_mode(sw_display_mode),
        .sw_time_edit   (sw_time_edit),
        .msec_watch     (w_msec_watch),
        .sec_watch      (w_sec_watch),
        .min_watch      (w_min_watch),
        .hour_watch     (w_hour_watch),
        .selected_digit (selected_digit)
    );


    //==================================================================
    // 4. SR04 Top
    //==================================================================

    sr04_top u_SR04_TOP (
        .clk          (clk),
        .rst          (rst),
        .en           (1'b1),
        .sr04_start   (sr04_start),
        .echo         (sr04_echo),
        .trigger      (sr04_trigger),
        .distance_low (w_distance_low),
        .distance_high(w_distance_high),
        .sr04_busy    (sr04_busy),
        .sr04_done    (sr04_done)
    );


    //==================================================================
    // 5. DHT11 Top
    //==================================================================

    dht11_top u_DHT11_TOP (
        .clk        (clk),
        .rst        (rst),
        .en         (1'b1),
        .dht11_start(dht11_start),

        .dht11_io(dht11_io),

        .dht11_valid(dht11_valid),
        .humidity   (w_humidity),
        .temperature(w_temperature),
        .dht11_busy (dht11_busy),
        .dht11_done (dht11_done)
    );


    //==================================================================
    // 6. Output Assignment
    //==================================================================

    // Stopwatch
    // [31:24] Hour
    // [23:16] Minute
    //  [15:8] Second 
    //   [7:0] Millisecond 
    assign o_stopwatch = {
        {3'b0, w_hour_stopwatch},
        {2'b0, w_min_stopwatch},
        {2'b0, w_sec_stopwatch},
        {1'b0, w_msec_stopwatch}
    };

    // Watch
    // [31:24] Hour
    // [23:16] Minute
    //  [15:8] Second
    //   [7:0] Millisecond
    assign o_watch = {
        {3'b0, w_hour_watch},
        {2'b0, w_min_watch},
        {2'b0, w_sec_watch},
        {1'b0, w_msec_watch}
    };

    // SR04
    // [7:0] distance_high, [7:0] distance_low
    assign o_sr04 = {16'd0, w_distance_high, w_distance_low};

    // DHT11
    // [31:16] Humidity
    //  [15:0] Temperature
    assign o_dht11 = {w_humidity, w_temperature};

endmodule

// --=================================================================--


// ===================================================================
// mux_4x1
// ===================================================================

module mux_4x1 (
    input  wire [1:0] sel,
    input  wire [31:0] in0,
    input  wire [31:0] in1,
    input  wire [31:0] in2,
    input  wire [31:0] in3,
    output reg  [31:0] mux_out
);

    always @(*) begin
        case (sel)
            2'd0:    mux_out = in0;
            2'd1:    mux_out = in1;
            2'd2:    mux_out = in2;
            2'd3:    mux_out = in3;
            default: mux_out = in0;
        endcase
    end

endmodule

// --=================================================================--


// ===================================================================
// btn_debounce
// ===================================================================

module btn_debounce (
    input  clk,
    input  rst,
    input  i_btn,
    output o_btn
);

    parameter F_COUNT = 100_000_000 / 1_000;

    reg [8:0] q_reg;
    reg edge_reg;
    wire debounce;

    reg [$clog2(F_COUNT)-1:0] counter_reg;
    reg tick_1KHz;

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            counter_reg <= 0;
            tick_1KHz <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if(counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                tick_1KHz <= 1'b1;
            end else begin
                tick_1KHz <= 1'b0;
            end
        end
    end

    // 8bit shift register : SIPO
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            q_reg <= 9'h000;
        end else begin
            if(tick_1KHz) begin
                q_reg <= {i_btn, q_reg[8:1]};
            end
        end
    end

    // 8-input AND gate
    assign debounce = &q_reg[7:0];

    // edge detection
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            edge_reg <= 1'b0;
        end else begin
            edge_reg <= debounce;
        end
    end

    // rising edge, tick gen
    assign o_btn = ~edge_reg & debounce; 

endmodule

// --=================================================================--
