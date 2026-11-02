`timescale 1ns / 1ps


// ===================================================================
// cmd_control_unit
// ===================================================================

module cmd_control_unit (
    input             clk,
    input             rst,
    // UART RX FIFO
    input      [ 7:0] rx_pop_data,
    input             rx_empty,
    output            rx_pop,
    // UART TX FIFO
    input             tx_full,
    output            tx_push,
    output     [ 7:0] tx_push_data,
    // datapath mux
    input             sw0,             // data show mode switch 0
    input             sw1,             // data show mode switch 1
    input      [31:0] display_data,    // fnd current show data
    // button
    input             btnR,
    input             btnL,
    input             btnD,
    input             btnU,
    // stopwatch control
    output reg        stopwatch_btnR,
    output reg        stopwatch_btnL,
    output reg        stopwatch_btnD,
    output reg        stopwatch_btnU,
    // watch control
    output reg        watch_btnR,
    output reg        watch_btnL,
    output reg        watch_btnD,
    output reg        watch_btnU,
    // SR04 control
    input             sr04_busy,
    output reg        sr04_start,
    // dht11 control
    input             dht11_busy,
    output reg        dht11_start
);

    wire w_cmdR, w_cmdL, w_cmdD, w_cmdU, w_status, w_cmdNONE;

    reg w_cmd_success, w_cmd_fail, w_cmd_none;

    ascii_decoder U_ASCII_DECODER (
        .clk    (clk),
        .rst    (rst),
        .enable (~rx_empty),
        .ascii  (rx_pop_data),
        .pop    (rx_pop),
        .mode1  (w_cmdR),
        .mode2  (w_cmdL),
        .mode3  (w_cmdD),
        .mode4  (w_cmdU),
        .status (w_status),
        .cmdNONE(w_cmdNONE)
    );

    ascii_sender U_ASCII_SENDER (
        .clk       (clk),
        .rst       (rst),
        .success   (w_cmd_success),
        .fail      (w_cmd_fail),
        .status    (w_status),
        .cmdNONE   (w_cmd_none),
        .send_data (display_data),
        .sw0       (sw0),
        .sw1       (sw1),
        .full      (tx_full),
        .split_byte(tx_push_data),
        .push      (tx_push)
    );

    always @(*) begin
        {watch_btnR, watch_btnL, watch_btnD, watch_btnU} = 4'b0000;
        {stopwatch_btnR, stopwatch_btnL, stopwatch_btnD, stopwatch_btnU} = 4'b0000;
        sr04_start = 1'b0;
        dht11_start = 1'b0;
        w_cmd_success = 1'b0;
        w_cmd_fail = 1'b0;
        w_cmd_none = 1'b0;

        case ({
            sw1, sw0
        })
            2'b00: begin
                {watch_btnR, watch_btnL, watch_btnD, watch_btnU} = {
                    btnR | w_cmdR, btnL | w_cmdL, btnD | w_cmdD, btnU | w_cmdU
                };
                w_cmd_success = (w_cmdR | w_cmdL | w_cmdD | w_cmdU);    // always success
                w_cmd_none = w_cmdNONE;
            end
            2'b01: begin
                {stopwatch_btnR, stopwatch_btnL, stopwatch_btnD, stopwatch_btnU}
                = {
                    btnR | w_cmdR, btnL | w_cmdL, btnD | w_cmdD, btnU | w_cmdU
                };
                w_cmd_success = (w_cmdR | w_cmdL | w_cmdD | w_cmdU);    // always success
                w_cmd_none = w_cmdNONE;
            end
            2'b10: begin
                sr04_start = (btnR | w_cmdR) && !sr04_busy;
                w_cmd_success = w_cmdR & !sr04_busy;
                w_cmd_fail = w_cmdR & sr04_busy;
                w_cmd_none = w_cmdNONE | w_cmdL | w_cmdD | w_cmdU;
            end
            2'b11: begin
                dht11_start = (btnR | w_cmdR) && !dht11_busy;
                w_cmd_success = w_cmdR & !dht11_busy;
                w_cmd_fail = w_cmdR & dht11_busy;
                w_cmd_none = w_cmdNONE | w_cmdL | w_cmdD | w_cmdU;
            end
        endcase
    end

endmodule

// --=================================================================--


// ===================================================================
// ascii_decoder
// ===================================================================

module ascii_decoder (
    input            clk,
    input            rst,
    input            enable,
    input      [7:0] ascii,
    output reg       pop,
    // output reg [3:0] bin,
    output reg       mode1,
    output reg       mode2,
    output reg       mode3,
    output reg       mode4,
    output reg       status,
    output reg       cmdNONE
);
    reg [7:0] data_reg, data_next;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            data_reg <= 0;
        end else begin
            data_reg <= data_next;
        end
    end
    always @(*) begin
        pop = 1'b0;
        data_next = data_reg;
        mode1 = 0;
        mode2 = 0;
        mode3 = 0;
        mode4 = 0;
        status = 0;
        cmdNONE = 0;
        if (enable) begin
            data_next = ascii;
            pop = 1'b1;

            case (ascii)
                //R ,r
                "R", "r": mode1 = 1;
                //L, l
                "L", "l": mode2 = 1;
                //D, d
                "D", "d": mode3 = 1;
                //U,u
                "U", "u": mode4 = 1;
                //S,s
                "S", "s": status = 1;
                default:  cmdNONE = 1;
            endcase
            // end else begin
            //     case (data_reg)
            //         8'h30: bin = 4'h0;
            //         8'h31: bin = 4'h1;
            //         8'h32: bin = 4'h2;
            //         8'h33: bin = 4'h3;
            //         8'h34: bin = 4'h4;
            //         8'h35: bin = 4'h5;
            //         8'h36: bin = 4'h6;
            //         8'h37: bin = 4'h7;
            //         8'h38: bin = 4'h8;
            //         8'h39: bin = 4'h9;

            //         //대문자,소문자
            //         8'h41, 8'h61: bin = 4'ha;
            //         8'h42, 8'h62: bin = 4'hb;
            //         8'h43, 8'h63: bin = 4'hc;
            //         8'h44, 8'h64: bin = 4'hd;
            //         8'h45, 8'h65: bin = 4'he;
            //         8'h46, 8'h66: bin = 4'hf;

            //         default: bin = 4'b0000;
            //     endcase
        end
    end

endmodule

// --=================================================================--


// ===================================================================
// ascii_sender
// ===================================================================

module ascii_sender (
    input         clk,
    input         rst,
    input         success,
    input         fail,
    input         status,
    input         cmdNONE,
    input  [31:0] send_data,
    input         sw0,
    input         sw1,
    input         full,
    output [ 7:0] split_byte,
    output        push,
    output        sender_busy
);
    reg [7:0] send_data_register[3:0];
    reg [7:0] split_byte_reg, split_byte_next;
    reg [3:0] counter_reg, counter_next;
    // 000 - watch, 100 - stopwatch, 010 - SR04, 110 - thd11 ,111 - success , 001 - fail,101 - NONE
    reg [2:0] mode_reg, mode_next;
    reg c_state, n_state;  // 0 - idel, 1 - send
    reg [3:0] d1, d10, d100;
    reg push_reg, push_next;
    reg sender_busy_reg, sender_busy_next;
    integer i;

    assign split_byte = split_byte_reg;
    assign push = push_reg;
    assign sender_busy = sender_busy_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            split_byte_reg <= 0;
            for (i = 0; i < 4; i = i + 1) send_data_register[i] <= 8'd0;
            counter_reg <= 0;
            c_state <= 0;
            mode_reg <= 0;
            push_reg <= 0;
            sender_busy_reg <= 0;
        end else begin
            split_byte_reg <= split_byte_next;
            counter_reg <= counter_next;
            c_state <= n_state;
            mode_reg <= mode_next;
            push_reg <= push_next;
            sender_busy_reg <= sender_busy_next;

            if (c_state == 0) begin
                if (status) begin
                    send_data_register[0] <= send_data[31:24];
                    send_data_register[1] <= send_data[23:16];
                    send_data_register[2] <= send_data[15:8];
                    send_data_register[3] <= send_data[7:0];
                end else if (success) begin
                    send_data_register[0] <= {"D"};
                    send_data_register[1] <= {"O"};
                    send_data_register[2] <= {"N"};
                    send_data_register[3] <= {"E"};
                end else if (fail) begin
                    send_data_register[0] <= {"F"};
                    send_data_register[1] <= {"A"};
                    send_data_register[2] <= {"I"};
                    send_data_register[3] <= {"L"};
                end else if (cmdNONE) begin
                    send_data_register[0] <= {"N"};
                    send_data_register[1] <= {"O"};
                    send_data_register[2] <= {"N"};
                    send_data_register[3] <= {"E"};
                end else
                    for (i = 0; i < 4; i = i + 1) send_data_register[i] <= 8'd0;
            end
        end
    end

    always @(*) begin
        n_state = c_state;
        mode_next = mode_reg;
        split_byte_next = split_byte_reg;
        counter_next = counter_reg;
        push_next = push_reg;
        sender_busy_next = sender_busy_reg;

        d100 = 4'b0;
        d10 = 4'b0;
        d1 = 4'b0;
        case (c_state)
            0: begin  //idle
                counter_next = 0;
                d100 = 4'b0;
                d10 = 4'b0;
                d1 = 4'b0;
                mode_next = 0;
                push_next = 0;
                sender_busy_next = 0;

                if (status) begin
                    mode_next = {sw0, sw1, 1'b0};
                    n_state = 1;
                    sender_busy_next = 1;
                end else if (success) begin
                    mode_next = 3'b111;
                    n_state = 1;
                    sender_busy_next = 1;
                end else if (fail) begin
                    mode_next = 3'b001;
                    n_state = 1;
                    sender_busy_next = 1;
                end else if (cmdNONE) begin
                    mode_next = 3'b101;
                    n_state = 1;
                    sender_busy_next = 1;
                end 
            end
            1: begin  //send

                if (!full) begin
                    if (mode_reg == 3'b000 || mode_reg == 3'b100) begin  //stopawatch, watch
                        push_next = 1;
                        counter_next = counter_reg + 1;
                        //00:00:00:00  에서 '00:' 이렇게 3개씩 묶음. 단 마지막에서는 : 출력 안함 
                        d1 = send_data_register[counter_reg/3] % 10;
                        d10 = send_data_register[counter_reg/3] / 10;
                        if (counter_reg == 4'd11) begin            // 마지막 스페이스
                            split_byte_next = 8'h20;
                        end else if (counter_reg == 4'd12) begin  // 끝
                            n_state = 0;  // CR/LF 상태를 추가했다면 2
                            push_next = 0;
                        end else if (counter_reg % 3 == 0) begin   // 10의 자리
                            split_byte_next = {4'h3, d10};
                        end else if (counter_reg % 3 == 1) begin   // 1의 자리
                            split_byte_next = {4'h3, d1};
                        end else begin  // ':'
                            split_byte_next = 8'h3A;
                        end
                    end

                    if (mode_reg == 3'b010) begin  // SR04- 거리
                        //거리 100,10,1 의 자리
                        d100 = send_data_register[2] % 10;
                        d10  = send_data_register[3] / 10;
                        d1   = send_data_register[3] % 10;

                        //100의 자리 (0이면 무시)
                        if (counter_reg == 0) begin
                            if (d100 == 4'b0) begin
                                counter_next = counter_reg + 1;
                            end else begin
                                counter_next = counter_reg + 1;
                                split_byte_next = {4'h3, d100};
                                push_next = 1;
                            end

                            //10의자리 (0이면 무시)
                        end else if (counter_reg == 1) begin
                            if (d100 == 4'b0 && d10 == 4'b0) begin
                                counter_next = counter_reg + 1;
                            end else begin
                                counter_next = counter_reg + 1;
                                split_byte_next = {4'h3, d10};
                                push_next = 1;
                            end

                            //1의 자리
                        end else if (counter_reg == 2) begin
                            counter_next = counter_reg + 1;
                            split_byte_next = {4'h3, d1};
                            push_next = 1;

                            // c 출력
                        end else if (counter_reg == 3) begin
                            counter_next = counter_reg + 1;
                            split_byte_next = 8'h63;
                            push_next = 1;

                            //m 출력
                        end else if (counter_reg == 4) begin
                            counter_next = counter_reg + 1;
                            split_byte_next = 8'h6D;
                            push_next = 1;
                            //공백 출력
                        end else if (counter_reg == 5) begin
                            counter_next = counter_reg + 1;
                            split_byte_next = 8'h20;  // ' '
                            push_next = 1;
                        end else begin
                            n_state   = 0;
                            push_next = 0;
                        end
                    end

                    if (mode_reg == 3'b110) begin  //dht11 - 온습도
                        counter_next = counter_reg + 1;
                        d1 = send_data_register[{counter_reg[2], 1'b0}] % 10;
                        d10 = send_data_register[{counter_reg[2], 1'b0}] / 10;


                        case (counter_reg)
                            4'd1: begin
                                split_byte_next = {4'h3, d10};  //습도 10
                                push_next = 1;
                            end
                            4'd2: begin
                                split_byte_next = {4'h3, d1};  //습도 1
                                push_next = 1;
                            end
                            4'd3: begin
                                split_byte_next = 8'h25;  // %
                                push_next = 1;
                            end
                            4'd4: begin
                                split_byte_next = {4'h3, d10};  //온도 10
                                push_next = 1;
                            end
                            4'd5: begin
                                split_byte_next = {4'h3, d1};  //온도 1
                                push_next = 1;
                            end
                            4'd6: begin
                                split_byte_next = 8'h2A;  // *
                                push_next = 1;
                            end
                            4'd7: begin
                                split_byte_next = 8'h43;  //C
                                push_next = 1;
                            end
                            4'd8: begin
                                split_byte_next = 8'h20;  // ' '
                                push_next = 1;
                            end
                            4'd9: begin
                                push_next = 0;
                                n_state   = 0;
                            end

                        endcase

                    end
                    if (mode_reg == 3'b001 ||mode_reg == 3'b101 ||mode_reg == 3'b111) begin  //fail , NONE

                        if (counter_reg < 3) begin
                            push_next = 1;
                            split_byte_next = send_data_register[counter_reg];
                            counter_next = counter_reg + 1;
                        end else if (counter_reg == 3) begin
                            push_next = 1;
                            counter_next = counter_reg + 1;
                            split_byte_next = send_data_register[counter_reg];
                        end else if (counter_reg == 4) begin
                            push_next = 1;
                            counter_next = counter_reg + 1;
                            split_byte_next = 8'h20;  // ' '
                        end else begin
                            n_state   = 0;
                            push_next = 0;
                        end
                    end

                    // if (mode_reg == 3'b111) begin  // ok
                    //     push_next = 1;
                    //     if (counter_reg == 0) begin
                    //         split_byte_next = send_data_register[counter_reg];
                    //         counter_next = counter_reg + 1;
                    //     end else if (counter_reg == 1) begin
                    //         split_byte_next = send_data_register[counter_reg];
                    //         n_state = 0;
                    //     end else begin
                    //         mode_next = 0;
                    //     end
                    // end

                end
            end
        endcase
    end

endmodule

// --=================================================================--
