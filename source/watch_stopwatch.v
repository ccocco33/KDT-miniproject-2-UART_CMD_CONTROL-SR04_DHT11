`timescale 1ns / 1ps


// ===================================================================
// stopwatch_top
// ===================================================================

module stopwatch_top (
    input             clk,
    input             rst,
    input             btnR,
    input             btnL,
    input             btnU,
    input             btnD,
    output      [6:0] msec_stopwatch,
    output      [5:0] sec_stopwatch,
    output      [5:0] min_stopwatch,
    output      [4:0] hour_stopwatch
);

    // Internal Control Signals
    wire w_clear;
    wire w_run_stop;
    wire w_mode;
    wire w_laptime;
    wire w_lap_cap;

    // Stopwatch Control Unit
    stopwatch_control_unit u_STOPWATCH_CONTROL_UNIT (
        .clk          (clk),
        .rst          (rst),
        .btn_run_stop (btnR),
        .btn_clear    (btnL),
        .btn_mode     (btnU),
        .btn_laptime  (btnD),
        .clear        (w_clear),
        .run_stop     (w_run_stop),
        .mode         (w_mode),
        .laptime      (w_laptime),
        .lap_cap      (w_lap_cap)
    );

    // Stopwatch Datapath
    stopwatch_datapath u_STOPWATCH_DATAPATH (
        .clk      (clk),
        .rst      (rst),
        .run_stop (w_run_stop),
        .clear    (w_clear),
        .mode     (w_mode),
        .laptime  (w_laptime),
        .lap_cap  (w_lap_cap),
        .msec     (msec_stopwatch),
        .sec      (sec_stopwatch),
        .min      (min_stopwatch),
        .hour     (hour_stopwatch)
    );

endmodule

// --===========================================================================--


// ===================================================================
// stopwatch_control_unit
// ===================================================================

module stopwatch_control_unit (
    input             clk,
    input             rst,
    input             btn_run_stop,
    input             btn_clear,
    input             btn_mode,
    input             btn_laptime, // timelapse operation
    output reg        clear,
    output reg        run_stop,
    output            mode,
    output            laptime, // display captured lap time
    output reg        lap_cap  // lap capture
);
    localparam STOP    = 3'b000;
    localparam RUN     = 3'b001;
    localparam CLEAR   = 3'b010; 
    localparam MODE    = 3'b011; 
    localparam LAPTIME = 3'b100;

    reg  [2:0] n_state, c_state;
    reg        mode_reg, mode_next; // mode_reg: currunt mode, mode_next: next mode

    assign mode = mode_reg;
    assign laptime = (c_state == LAPTIME);

    // Sequential Logic
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state  <= STOP;
            mode_reg <= 1'b0;
        end 
        else begin
            c_state  <= n_state;
            mode_reg <= mode_next;
        end
    end

    // Next State and Output Assignment
    always @(*) begin
        n_state = c_state;
        run_stop = 1'b0;
        clear = 1'b0;
        mode_next = mode_reg;
        lap_cap = 1'b0;

        case (c_state)
            STOP: begin
                run_stop = 1'b0;
                clear = 1'b0;

                if (btn_run_stop == 1'b1) begin
                    n_state = RUN;
                end 
                else if (btn_clear == 1'b1) begin
                    n_state = CLEAR;
                end 
                else if (btn_mode == 1'b1) begin
                    n_state = MODE;
                end
            end

            RUN: begin
                run_stop = 1'b1;

                if (btn_run_stop == 1'b1) begin
                    n_state = STOP;
                end 
                else if (btn_laptime == 1'b1) begin
                    n_state = LAPTIME;
                    lap_cap = 1'b1;
                end
            end

            CLEAR: begin
                clear   = 1'b1;
                n_state = STOP;
            end

            MODE: begin
                mode_next = ~mode_reg;
                n_state   = STOP;
            end

            LAPTIME: begin
                run_stop = 1'b1;

                if (btn_run_stop) begin
                    n_state = STOP;
                end 
                else if (btn_laptime) begin
                    lap_cap = 1'b1;
                end
            end

            default: begin
                n_state = STOP;
            end
        endcase
    end

endmodule

// --===========================================================================--


// ===================================================================
// stopwatch_datapath
// ===================================================================

module stopwatch_datapath #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input clk,
    input rst,
    input run_stop,
    input clear,
    input mode,
    input laptime, // 저장된 랩 시간 표시
    input lap_cap, // 현재 시간 저장 신호
    output [MSEC_BIT_WIDTH-1:0] msec,
    output [SEC_BIT_WIDTH-1:0] sec,
    output [MIN_BIT_WIDTH-1:0] min,
    output [HOUR_BIT_WIDTH-1:0] hour
);

    wire w_tick_10ms, w_tick_sec, w_tick_min, w_tick_hour;

    wire [ MSEC_BIT_WIDTH -1 :0] w_lap_msec;
    wire [  SEC_BIT_WIDTH -1 :0] w_lap_sec;
    wire [  MIN_BIT_WIDTH -1 :0] w_lap_min;
    wire [ HOUR_BIT_WIDTH -1 :0] w_lap_hour;
    wire [ MSEC_BIT_WIDTH -1 :0] w_count_msec;
    wire [  SEC_BIT_WIDTH -1 :0] w_count_sec;
    wire [  MIN_BIT_WIDTH -1 :0] w_count_min;
    wire [ HOUR_BIT_WIDTH -1 :0] w_count_hour;

    mux_2x1x4_lapstop #(
    .MSEC_BIT_WIDTH(MSEC_BIT_WIDTH),
    .SEC_BIT_WIDTH(SEC_BIT_WIDTH),
    .MIN_BIT_WIDTH(MIN_BIT_WIDTH),
    .HOUR_BIT_WIDTH(HOUR_BIT_WIDTH)
) U_MUX_LAP_STOPWATCH (
    .msec_lap(w_lap_msec),
    .sec_lap(w_lap_sec),
    .min_lap(w_lap_min),
    .hour_lap(w_lap_hour),
    .msec_stopwatch(w_count_msec),
    .sec_stopwatch(w_count_sec),
    .min_stopwatch(w_count_min),
    .hour_stopwatch(w_count_hour),
    .laptime(laptime),
    .msec_result(msec),
    .sec_result(sec),
    .min_result(min),
    .hour_result(hour) 
);

    stopwatch_laptime #(
    .MSEC_BIT_WIDTH (MSEC_BIT_WIDTH),
    .SEC_BIT_WIDTH  (SEC_BIT_WIDTH),
    .MIN_BIT_WIDTH  (MIN_BIT_WIDTH),
    .HOUR_BIT_WIDTH (HOUR_BIT_WIDTH)
) U_STOPWATCH_LAPTIME (
    .clk    (clk),
    .rst    (rst),
    .clear  (clear),
    .laptime(laptime),
    .lap_cap(lap_cap),    
    .i_msec(w_count_msec),
    .i_sec (w_count_sec),
    .i_min (w_count_min),
    .i_hour(w_count_hour),           
    .o_msec(w_lap_msec),
    .o_sec (w_lap_sec),
    .o_min (w_lap_min),
    .o_hour(w_lap_hour)  
);


    tick_counter #(
        .TIMES    (24),
        .BIT_WIDTH(HOUR_BIT_WIDTH)
    ) U_HOUR_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_hour),
        .clear     (clear),
        .mode      (mode),
        .time_count(w_count_hour),
        .o_tick    ()
    );
    tick_counter #(
        .TIMES    (60),
        .BIT_WIDTH(MIN_BIT_WIDTH)
    ) U_MIN_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_min),
        .clear     (clear),
        .mode      (mode),
        .time_count(w_count_min),
        .o_tick    (w_tick_hour)
    );
    tick_counter #(
        .TIMES    (60),
        .BIT_WIDTH(SEC_BIT_WIDTH)
    ) U_SEC_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_sec),
        .clear     (clear),
        .mode      (mode),
        .time_count(w_count_sec),
        .o_tick    (w_tick_min)
    );
    tick_counter #(
        .TIMES    (100),
        .BIT_WIDTH(MSEC_BIT_WIDTH)
    ) U_MSEC_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_10ms),
        .clear     (clear),
        .mode      (mode),
        .time_count(w_count_msec),
        .o_tick    (w_tick_sec)
    );

    tick_gen_100hz U_TICK_GEN_100HZ (
        .clk     (clk),
        .rst     (rst),
        .run_stop(run_stop),
        .clear   (clear),
        .o_tick  (w_tick_10ms)
    );

endmodule

// --===========================================================================--


// ===================================================================
// stopwatch_laptime
// ===================================================================

module stopwatch_laptime #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input                          clk,
    input                          rst,
    input                          clear,
    input                          laptime,
    input                          lap_cap,
 
    //해당 카운팅 된 시간이 들어옴 
    input [ MSEC_BIT_WIDTH -1 :0]  i_msec,
    input [  SEC_BIT_WIDTH -1 :0]  i_sec,
    input [  MIN_BIT_WIDTH -1 :0]  i_min,
    input [ HOUR_BIT_WIDTH -1 :0]  i_hour,
    // 저장된 시간 출력              
    output [ MSEC_BIT_WIDTH -1 :0] o_msec,
    output [  SEC_BIT_WIDTH -1 :0] o_sec,
    output [  MIN_BIT_WIDTH -1 :0] o_min,
    output [ HOUR_BIT_WIDTH -1 :0] o_hour  
);

    reg [ MSEC_BIT_WIDTH -1 :0] lap_msec;
    reg [  SEC_BIT_WIDTH -1 :0] lap_sec;
    reg [  MIN_BIT_WIDTH -1 :0] lap_min;
    reg [ HOUR_BIT_WIDTH -1 :0] lap_hour;

    always @(posedge clk, posedge rst) begin
        if(rst | clear) begin
            lap_msec <= 0;
            lap_sec  <= 0;
            lap_min  <= 0;
            lap_hour <= 0;
        end else if (lap_cap) begin
            lap_msec <= i_msec;
            lap_sec  <= i_sec;
            lap_min  <= i_min;
            lap_hour <= i_hour;
        end
    end

    assign o_msec = lap_msec;  
    assign o_sec  = lap_sec;
    assign o_min  = lap_min;
    assign o_hour = lap_hour;  

endmodule

// --===========================================================================--


// ===================================================================
// mux_2x1x4_lapstop
// ===================================================================

module mux_2x1x4_lapstop #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input      [MSEC_BIT_WIDTH-1:0] msec_lap,
    input      [ SEC_BIT_WIDTH-1:0]  sec_lap,
    input      [ MIN_BIT_WIDTH-1:0]  min_lap,
    input      [HOUR_BIT_WIDTH-1:0] hour_lap,
    input      [MSEC_BIT_WIDTH-1:0] msec_stopwatch,
    input      [ SEC_BIT_WIDTH-1:0]  sec_stopwatch,
    input      [ MIN_BIT_WIDTH-1:0]  min_stopwatch,
    input      [HOUR_BIT_WIDTH-1:0] hour_stopwatch,
    input                           laptime,
    output     [MSEC_BIT_WIDTH-1:0] msec_result,
    output     [ SEC_BIT_WIDTH-1:0]  sec_result,
    output     [ MIN_BIT_WIDTH-1:0]  min_result,
    output     [HOUR_BIT_WIDTH-1:0] hour_result
);
    assign msec_result = laptime ? msec_lap : msec_stopwatch;
    assign sec_result  = laptime ? sec_lap  : sec_stopwatch;
    assign min_result  = laptime ? min_lap  : min_stopwatch;
    assign hour_result = laptime ? hour_lap : hour_stopwatch;
    
endmodule

// --===========================================================================--


// ===================================================================
// tick_counter
// ===================================================================

module tick_counter #(
    parameter TIMES = 100,
    BIT_WIDTH = 7
) (
    input                      clk,
    input                      rst,
    input                      i_tick,
    input                      clear,
    input                      mode,
    output     [BIT_WIDTH-1:0] time_count,
    output reg                 o_tick
);
    reg [$clog2(TIMES)-1:0] counter_reg;
    assign time_count = counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst | clear) begin
            counter_reg <= 0;
            o_tick <= 1'b0;
        end else begin
            if (mode) begin  //mode = 1 , down
                if (i_tick) begin
                    counter_reg <= counter_reg - 1;
                    if (counter_reg == 0) begin
                        o_tick <= 1'b1;
                        counter_reg <= TIMES - 1;
                    end
                end else begin  // 이거 없으면 w_tick_sec 계속 1됨, 
                    o_tick <= 1'b0;
                end
            end else begin  //mode = 0 , up
                if (i_tick) begin
                    counter_reg <= counter_reg + 1;
                    if (counter_reg == TIMES - 1) begin
                        o_tick <= 1'b1;
                        counter_reg <= 0;
                    end
                end else begin
                    o_tick <= 1'b0;
                end
            end
        end
    end
endmodule

// --===========================================================================--


// ===================================================================
// tick_gen_100hz
// ===================================================================

module tick_gen_100hz (
    input      clk,
    input      rst,
    input      run_stop,
    input      clear,
    output reg o_tick
);
    //100M->100hz
    parameter F_COUNT = 100_000_000 / 100;
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst | clear) begin
            counter_reg <= 0;
            o_tick <= 1'b0;
        end else begin
            if (run_stop) begin
                counter_reg <= counter_reg + 1;
                if (counter_reg == (F_COUNT - 1)) begin
                    counter_reg <= 0;
                    o_tick <= 1'b1;
                end else begin
                    o_tick <= 1'b0;
                end
            end else begin
                //run_stop 1 and o_tick 1 => run_stop 이 0으로 바뀌면 o_tick 계속 1 인 경우 해결용.
                o_tick <= 1'b0;
            end
        end
    end

endmodule

// --===========================================================================--


// ===================================================================
// watch_top
// ===================================================================

module watch_top (
    input             clk,
    input             rst,
    input             btnR,
    input             btnL,
    input             btnU,
    input             btnD,
    // input       [1:0] sw_show_mode,
    input             sw_display_mode,
    input             sw_time_edit,
    output      [6:0] msec_watch,
    output      [5:0] sec_watch,
    output      [5:0] min_watch,
    output      [4:0] hour_watch,
    output      [1:0] selected_digit
);

    //==================================================================
    // 1. Wire Declaration
    //==================================================================

    wire       w_up_control_unit;
    wire       w_down_control_unit;
    wire       w_edit;
    wire [1:0] w_selected_digit;


    //==================================================================
    // 3. Watch Controller
    //==================================================================

    assign selected_digit = w_selected_digit;


    //==================================================================
    // 3. Watch Controller
    //==================================================================

    watch_control_unit u_WATCH_CONTROL_UNIT (
        .clk             (clk),
        .rst             (rst),
        .btn_R           (btnR),
        .btn_L           (btnL),
        .btn_U           (btnU),
        .btn_D           (btnD),
        // .sw_show_mode    (sw_show_mode),
        .sw_display_mode (sw_display_mode),
        .sw_time_edit    (sw_time_edit),
        .up              (w_up_control_unit),
        .down            (w_down_control_unit),
        .run_stop        (w_edit),
        .selected_digit  (w_selected_digit)
    );


    //==================================================================
    // 4. Watch Datapath
    //==================================================================

    watch_datapath u_WATCH_DATAPATH (
        .clk             (clk),
        .rst             (rst),
        // .sw_show_mode    (sw_show_mode),
        .sw_display_mode (sw_display_mode),
        .edit            (w_edit),
        .up              (w_up_control_unit),
        .down            (w_down_control_unit),
        .selected_digit  (w_selected_digit),
        .msec            (msec_watch),
        .sec             (sec_watch),
        .min             (min_watch),
        .hour            (hour_watch)
    );


endmodule

// --===========================================================================--


// ===================================================================
// watch_control_unit
// ===================================================================

module watch_control_unit (
    input            clk,
    input            rst,
    input            btn_R,
    input            btn_L,
    input            btn_U,
    input            btn_D,
    input            sw_display_mode, // SW0: Display Digit Selection, Unused inside of CU
    // input            sw_show_mode,    // SW1: 0 = Watch, 1 = Stopwatch
    input            sw_time_edit,    // SW2: 0 = General, 1 = Time Setting
    output reg       up,
    output reg       down,            // 0 = Increase, 1 = Decrease
    output reg       run_stop,        // Run = 0, Stop = 1
    output reg [1:0] selected_digit
);

    // States
    localparam WATCH = 3'b000;
    localparam S1    = 3'b001;
    localparam S10   = 3'b010;
    localparam S100  = 3'b011;
    localparam S1000 = 3'b100;

    // State Register
    reg  [2:0] c_state, n_state;
    reg        mode_reg, mode_next;

    // Sequential Logic
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state  <= WATCH;
            mode_reg <= 1'b0;
            up       <= 0;
            down     <= 0;
            run_stop <= 0;
        end 
        else begin
            c_state  <= n_state;
            mode_reg <= mode_next;
            run_stop <= sw_time_edit;
            up       <= btn_U;
            down     <= btn_D;
        end
    end

    // Next State, Output Logic
    always @(*) begin
        n_state        = c_state;
        selected_digit = 2'd0;

        if (sw_time_edit == 0) begin
            // Move back to Watch State if SW2 is off
            n_state = WATCH;
        end 
        else begin
            // watch 시간조절
            case (c_state)
                WATCH: begin
                    n_state = S1;
                end

                S1: begin
                    selected_digit = 2'b00;

                    if (btn_R) begin
                        n_state = S1000;
                    end 
                    else if (btn_L) begin
                        n_state = S10;
                    end 
                    else begin
                        n_state = S1;
                    end
                end

                S10: begin
                    selected_digit = 2'b01;

                    if (btn_R) begin
                        n_state = S1;
                    end 
                    else if (btn_L) begin
                        n_state = S100;
                    end 
                    else begin
                        n_state = S10;
                    end
                end

                S100: begin
                    selected_digit = 2'b10;

                    if (btn_R) begin
                        n_state = S10;
                    end 
                    else if (btn_L) begin
                        n_state = S1000;
                    end 
                    else begin
                        n_state = S100;
                    end
                end

                S1000: begin
                    selected_digit = 2'b11;

                    if (btn_R) begin
                        n_state = S100;
                    end 
                    else if (btn_L) begin
                        n_state = S1;
                    end 
                    else begin
                        n_state = S1000;
                    end
                end

                default: begin
                    n_state = WATCH;
                end
            endcase
        end
    end

endmodule

// --===========================================================================--


// ===================================================================
// watch_datapath
// ===================================================================

module watch_datapath #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input                       clk,
    input                       rst,
    // input                 [1:0] sw_show_mode,
    input                       sw_display_mode,
    input                       edit,
    input                       up,
    input                       down,
    input                 [1:0] selected_digit,
    output [MSEC_BIT_WIDTH-1:0] msec,
    output  [SEC_BIT_WIDTH-1:0] sec,
    output  [MIN_BIT_WIDTH-1:0] min,
    output [HOUR_BIT_WIDTH-1:0] hour
);

    wire w_tick_10ms, w_tick_sec, w_tick_min, w_tick_hour;
    //hour
    tick_counter_watch #(
        .TIMES       (24),
        .BIT_WIDTH   (HOUR_BIT_WIDTH),
        .UNIT_OF_TIME(2'b11)            // 00 - msec,01 sec,10-min, 11-hour
    ) U_HOUR_COUNTER_WATCH (
        .clk(clk),
        .rst(rst),
        .i_tick(w_tick_hour),
        .up(up),
        .down(down),
        .sw_display_mode(sw_display_mode),
        .edit(edit),
        .selected_digit(selected_digit),
        .time_count(hour),
        .o_tick()
    );
    //min
    tick_counter_watch #(
        .TIMES       (60),
        .BIT_WIDTH   (MIN_BIT_WIDTH),
        .UNIT_OF_TIME(2'b10)            // 00 - msec,01 sec,10-min, 11-hour
    ) U_MIN_COUNTER_WATCH (
        .clk(clk),
        .rst(rst),
        .i_tick(w_tick_min),
        .up(up),
        .down(down),
        .sw_display_mode(sw_display_mode),
        .edit(edit),
        .selected_digit(selected_digit),
        .time_count(min),
        .o_tick(w_tick_hour)
    );
    //SEC
    tick_counter_watch #(
        .TIMES       (60),
        .BIT_WIDTH   (SEC_BIT_WIDTH),
        .UNIT_OF_TIME(2'b01)            // 00 - msec,01 sec,10-min, 11-hour
    ) U_SEC_COUNTER_WATCH (
        .clk(clk),
        .rst(rst),
        .i_tick(w_tick_sec),
        .up(up),
        .down(down),
        .sw_display_mode(sw_display_mode),
        .edit(edit),
        .selected_digit(selected_digit),
        .time_count(sec),
        .o_tick(w_tick_min)
    );
    //MSEC
    tick_counter_watch #(
        .TIMES       (100),
        .BIT_WIDTH   (MSEC_BIT_WIDTH),
        .UNIT_OF_TIME(2'b00)            // 00 - msec,01 sec,10-min, 11-hour
    ) U_MSEC_COUNTER_WATCH (
        .clk(clk),
        .rst(rst),
        .i_tick(w_tick_10ms),
        .up(up),
        .down(down),
        .sw_display_mode(sw_display_mode),
        .edit(edit),
        .selected_digit(selected_digit),
        .time_count(msec),
        .o_tick(w_tick_sec)
    );

    tick_gen_100hz_watch U_TICK_GEN_100HZ_WATCH (
        .clk    (clk),
        .rst    (rst),
        .o_tick (w_tick_10ms)
    );

endmodule

// --=================================================================--


// ===================================================================
// tick_counter_watch
// ===================================================================

module tick_counter_watch #(
    parameter TIMES = 100,
    BIT_WIDTH = 7,
    UNIT_OF_TIME = 2'b00  // 00 - msec,01 sec,10-min, 11-hour
) (
    input                      clk,
    input                      rst,
    input                      i_tick,
    input                      up,
    input                      down,
    input                      sw_display_mode,
    input                      edit,
    input      [          1:0] selected_digit,
    output     [BIT_WIDTH-1:0] time_count,
    output reg                 o_tick
);
    reg [$clog2(TIMES)-1:0] counter_reg;
    // reg [$clog2(TIMES)-1:0] counter_next;
    assign time_count = counter_reg;
    localparam max = TIMES - 1;
    localparam max_1 = max % 10;  //1의 자리 최댓값
    localparam max_10 = max / 10;  //10의 자리 최댓값
    wire [3:0] counter_ds1 = counter_reg % 10;  //지금 1자리
    wire [3:0] counter_ds10 = counter_reg / 10;  //지금 10자리
    reg [3:0] counter_next_ds1;
    reg [3:0] counter_next_ds10;
    //sw_display_mode,UNIT_OF_TIME, selected_digit을 가지고 지금 내가 수정하는것인지 알아야한다.
    wire [1:0]edit_this_module = (sw_display_mode)? ((selected_digit[1]?2'b11:2'b10)):(selected_digit[1]?2'b01:2'b00); //(hour:min):(sec:msec)

    always @(*) begin
        counter_next_ds10 = counter_ds10;
        counter_next_ds1  = counter_ds1;
        if (selected_digit[0]) begin  //ds10,ds1000 더하기 빼기 10씩 되는곳
            if (up) begin
                //1자리가 1의자리 맥스보다 크다면 10의 자리는 10의자리 맥스보다 1작은 수가 최대가 된다. 아니라면 10의자리 맥스까지 가능하다.
                counter_next_ds10 = (counter_ds1 > max_1) ? ((counter_ds10 == max_10 - 1) ? 0 : counter_ds10 + 1)
                                                          : ((counter_ds10 == max_10)     ? 0 : counter_ds10 + 1);
            end else if (down) begin  // ds1,ds100 //빼기 10씩
                //1의 자리 확인 -> 1의 자리 맥스보다 크면 max10보다 1 작은거가 최대 / 1의자리 맥스보다 작으면 max 10까지 돌수있음
                counter_next_ds10 = (counter_ds1 > max_1) ? ((counter_ds10 == 0) ? max_10 - 1 : counter_ds10 - 1)
                                                          : ((counter_ds10 == 0) ? max_10     : counter_ds10 - 1);
            end
        end else begin  //ds1,ds100 더하기 빼기 1씩 되는곳
            if (up) begin
                counter_next_ds1 = (counter_ds10 == max_10) ? ((counter_ds1 == max_1) ? 0 : counter_ds1 + 1)
                                                            : ((counter_ds1 == 9)     ? 0 : counter_ds1 + 1);
            end else if (down) begin  // ds1,ds100 // 빼기 1씩
                //10의자리 == max_10?
                counter_next_ds1 = (counter_ds10 == max_10) ? ((counter_ds1 == 0) ? max_1 : counter_ds1 - 1)
                                                            : ((counter_ds1 == 0) ? 9     : counter_ds1 - 1);
            end
        end

    end

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            o_tick <= 1'b0;
            if (UNIT_OF_TIME == 2'b11) begin //hour은 12로 초기화
                    counter_reg <= 5'b01100;
            end else begin
                counter_reg <= 0;
            end
        end else begin
            o_tick <= 1'b0;
            if (edit) begin  // 수정 모드
                if (edit_this_module == UNIT_OF_TIME) begin
                    counter_reg <= counter_next_ds10 * 10 + counter_next_ds1;
                end else begin
                    counter_reg <=counter_reg;
                end
            end else begin  //수정 모드 x
                if (i_tick) begin
                    counter_reg <= counter_reg + 1;
                    if (counter_reg == max) begin
                        o_tick <= 1'b1;
                        counter_reg <= 0;
                    end else begin  // 이거 없으면 w_tick_sec 계속 1됨, 
                        o_tick <= 1'b0;
                    end

                end
            end

        end
    end
endmodule

// --=================================================================--


// ===================================================================
// tick_gen_100hz_watch
// ===================================================================

module tick_gen_100hz_watch (
    input      clk,
    input      rst,
    output reg o_tick
);
    //100M->100hz
    parameter F_COUNT = 100_000_000 / 100;
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            o_tick <= 1'b0;
        end else begin
            
                counter_reg <= counter_reg + 1;
                if (counter_reg == (F_COUNT - 1)) begin
                    counter_reg <= 0;
                    o_tick <= 1'b1;
                end else begin
                    o_tick <= 1'b0;
                end
            
        end
    end

endmodule

// --=================================================================--
