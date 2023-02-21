`timescale 1ns / 1ps



module axis_register #(
    parameter integer BYTE_WIDTH = 1,
    parameter integer USER_WIDTH = 0
) (
    input logic CLK  ,
    input logic RESET,
    input  logic [(BYTE_WIDTH*8)-1:0] S_AXIS_TDATA ,
    input  logic [  (BYTE_WIDTH-1):0] S_AXIS_TKEEP ,
    input  logic [  (USER_WIDTH-1):0] S_AXIS_TUSER ,
    input  logic                      S_AXIS_TVALID,
    output logic                      S_AXIS_TREADY,
    input  logic                      S_AXIS_TLAST ,
    output logic [(BYTE_WIDTH*8)-1:0] M_AXIS_TDATA ,
    output logic [  (BYTE_WIDTH-1):0] M_AXIS_TKEEP ,
    output logic [  (USER_WIDTH-1):0] M_AXIS_TUSER ,
    output logic                      M_AXIS_TVALID,
    input  logic                      M_AXIS_TREADY,
    output logic                      M_AXIS_TLAST
);


    // typedef enum {
    localparam [1:0] RESET_ST = 2'b00;
    localparam [1:0] IDLE_ST  = 2'b10;
    localparam [1:0] ONE_ST   = 2'b11;
    localparam [1:0] FULL_ST  = 2'b01;
    // } fsm;

    (* fsm_encoding = "none" *)logic [1:0] current_state = RESET_ST;
    logic [1:0][((BYTE_WIDTH*8)-1):0] data_reg                ;
    logic [1:0][    (BYTE_WIDTH-1):0] keep_reg                ;
    logic [1:0]                       last_reg                ;

    logic                    sel_rd        = 1'b0    ;
    logic                    sel_wr        = 1'b0    ;
    logic                    load_a                  ;
    logic                    load_b                  ;

    always_comb begin : M_AXIS_TVALID_processing 
        if (!current_state[0]) begin 
            M_AXIS_TVALID = 1'b0;
        end else begin 
            M_AXIS_TVALID = 1'b1;
        end 
    end 

    always_comb begin : S_AXIS_TREADY_processing 
        if (current_state[1]) begin 
            S_AXIS_TREADY = 1'b1;
        end else begin 
            S_AXIS_TREADY = 1'b0;
        end 
    end 

    always @(posedge CLK) begin 
        if (RESET) begin
            current_state <= RESET_ST;
        end else begin 
            case (current_state)
                IDLE_ST:
                    if (S_AXIS_TVALID) begin 
                        current_state <= ONE_ST;
                    end else begin 
                        current_state <= current_state;
                    end 
                
                ONE_ST:
                    if (S_AXIS_TVALID & ~M_AXIS_TREADY) begin 
                        current_state <= FULL_ST;
                    end else begin 
                        if (~S_AXIS_TVALID & M_AXIS_TREADY) begin 
                            current_state <= IDLE_ST;
                        end else begin 
                            current_state <= current_state;
                        end 
                    end 
            
                FULL_ST:
                    if (M_AXIS_TREADY) begin 
                        current_state <= ONE_ST;
                    end else begin 
                        current_state <= current_state;
                    end 
            
                default:
                    current_state <= IDLE_ST;
            endcase
        end
    end

    always_ff @(posedge CLK) begin 
        if (RESET) begin
            sel_rd <= 1'b0;
        end else begin
            sel_rd <= (M_AXIS_TREADY & M_AXIS_TVALID) ? ~sel_rd : sel_rd;
        end
    end

    always_comb begin : load_a_processing 
        load_a = ~sel_wr & (current_state != FULL_ST);
    end 

    always_comb begin : load_b_processing 
        load_b = sel_wr & (current_state != FULL_ST);
    end 

    always_ff @(posedge CLK) begin 
        if (RESET) begin
            sel_wr <= 1'b0;
        end else begin
            if (S_AXIS_TREADY & S_AXIS_TVALID) begin 
                sel_wr <= ~sel_wr;
            end else begin 
                sel_wr <= sel_wr;
            end 
        end
    end

    always_ff @(posedge CLK) begin : data_reg_0_processing 
        if (load_a) begin 
            data_reg[0] <= S_AXIS_TDATA;
        end else begin 
            data_reg[0] <= data_reg[0];
        end 
    end

    always_ff @(posedge CLK) begin : data_reg_1_processing 
        if (load_b) begin 
            data_reg[1] <= S_AXIS_TDATA;
        end else begin 
            data_reg[1] <= data_reg[1];
        end 
        // data_reg_1 <= load_b ? S_AXIS_TDATA : data_reg_1;
    end

    always_ff @(posedge CLK) begin : keep_reg_0_processing 
        if (load_a) begin 
            keep_reg[0] <= S_AXIS_TKEEP;
        end else begin 
            keep_reg[0] <= keep_reg[0];
        end 
    end

    always_ff @(posedge CLK) begin : keep_reg_1_processing 
        if (load_b) begin 
            keep_reg[1] <= S_AXIS_TKEEP;
        end else begin 
            keep_reg[1] <= keep_reg[1];
        end 
        // data_reg_1 <= load_b ? S_AXIS_TDATA : data_reg_1;
    end

    always_ff @(posedge CLK) begin : last_reg_0_processing 
        if (load_a) begin 
            last_reg[0] <= S_AXIS_TLAST;
        end else begin 
            last_reg[0] <= last_reg[0];
        end 
    end

    always_ff @(posedge CLK) begin : last_reg_1_processing 
        if (load_b) begin 
            last_reg[1] <= S_AXIS_TLAST;
        end else begin 
            last_reg[1] <= last_reg[1];
        end 
        // data_reg_1 <= load_b ? S_AXIS_TDATA : data_reg_1;
    end

    always_comb begin  
        if (sel_rd) begin 
            M_AXIS_TDATA = data_reg[1];
        end else begin 
            M_AXIS_TDATA = data_reg[0];
        end 
    end 

    always_comb begin  
        if (sel_rd) begin 
            M_AXIS_TKEEP = keep_reg[1];
        end else begin 
            M_AXIS_TKEEP = keep_reg[0];
        end 
    end 

    always_comb begin  
        if (sel_rd) begin 
            M_AXIS_TLAST = last_reg[1];
        end else begin 
            M_AXIS_TLAST = last_reg[0];
        end 
    end 

    generate
        if (USER_WIDTH > 0) begin

            logic [1:0][(USER_WIDTH-1):0] user_reg;

            always_ff @(posedge CLK) begin : user_reg_0_processing
                if (load_a) begin
                    user_reg[0] <= S_AXIS_TUSER;
                end else begin
                    user_reg[0] <= user_reg[0];
                end
            end

            always_ff @(posedge CLK) begin : user_reg_1_processing
                if (load_b) begin
                    user_reg[1] <= S_AXIS_TUSER;
                end else begin
                    user_reg[1] <= user_reg[1];
                end
            end

            always_comb begin
                if (sel_rd) begin
                    M_AXIS_TUSER = user_reg[1];
                end else begin
                    M_AXIS_TUSER = user_reg[0];
                end
            end
        end 

    endgenerate

endmodule : axis_register