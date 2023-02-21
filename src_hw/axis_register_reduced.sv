`timescale 1ns / 1ps



module axis_register_reduced #(
    parameter integer BYTE_WIDTH = 8,
    parameter integer USER_WIDTH = 8
) (
    input  logic                      CLK          ,
    input  logic                      RESET        ,
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


   (* srl_style = "register" *)logic [(BYTE_WIDTH*8)-1:0] data_reg ;
   (* srl_style = "register" *)logic [  (BYTE_WIDTH-1):0] keep_reg ;
   (* srl_style = "register" *)logic                      last_reg ;


    typedef enum {
        RESET_ST, // 00
        IDLE_ST,  // 10
        FULL_ST   // 01
    } fsm;

    (* fsm_encoding = "none" *) fsm current_state = RESET_ST;


    always_comb begin : M_AXIS_TVALID_processing 
        if (current_state == RESET_ST || current_state == IDLE_ST) begin 
            M_AXIS_TVALID = 1'b0;
        end else begin 
            M_AXIS_TVALID = 1'b1;
        end 
    end 

    always_comb begin : S_AXIS_TREADY_processing 
        // if ((current_state == FULL_ST & M_AXIS_TREADY) || current_state == IDLE_ST) begin 
        if (M_AXIS_TREADY) begin 
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
                    if (S_AXIS_TVALID & S_AXIS_TREADY) begin 
                        current_state <= FULL_ST;
                    end else begin 
                        current_state <= current_state;
                    end 
   
                FULL_ST:
                    // if (M_AXIS_TREADY & (!S_AXIS_TVALID)) begin 
                    if ((M_AXIS_TREADY & (!S_AXIS_TVALID)) | (M_AXIS_TREADY & M_AXIS_TVALID & !S_AXIS_TVALID)) begin 
                        current_state <= IDLE_ST;
                    end else begin 
                        current_state <= current_state;
                    end 
            
                default:
                    current_state <= IDLE_ST;

            endcase
        end
    end
 

    // always_ff @(posedge CLK) begin : data_reg_processing 
    //     if (M_AXIS_TREADY) begin 
    //         M_AXIS_TDATA <= S_AXIS_TDATA;
    //     end else begin 
    //         M_AXIS_TDATA <= M_AXIS_TDATA;
    //     end 
    // end

    always_ff @(posedge CLK) begin : data_reg_processing 
        if (M_AXIS_TREADY) begin 
            data_reg <= S_AXIS_TDATA;
        end else begin 
            data_reg <= data_reg;
        end 
    end

    always_comb begin : M_AXIS_TDATA_processing 
        M_AXIS_TDATA = data_reg;
    end 
    // always_ff @(posedge CLK) begin : keep_reg_processing 
    //     if (M_AXIS_TREADY) begin 
    //         M_AXIS_TKEEP <= S_AXIS_TKEEP;
    //     end else begin 
    //         M_AXIS_TKEEP <= M_AXIS_TKEEP;
    //     end 
    // end

    always_ff @(posedge CLK) begin : keep_reg_processing 
        if (M_AXIS_TREADY) begin 
            keep_reg <= S_AXIS_TKEEP;
        end else begin 
            keep_reg <= keep_reg;
        end 
    end

    always_comb begin : M_AXIS_TKEEP_processing 
        M_AXIS_TKEEP = keep_reg;
    end 
    // always_ff @(posedge CLK) begin : last_reg_processing 
    //     if (M_AXIS_TREADY) begin 
    //         M_AXIS_TLAST <= S_AXIS_TLAST;
    //     end else begin 
    //         M_AXIS_TLAST <= M_AXIS_TLAST;
    //     end 
    // end

    always_ff @(posedge CLK) begin : last_reg_processing 
        if (M_AXIS_TREADY) begin 
            last_reg <= S_AXIS_TLAST;
        end else begin 
            last_reg <= last_reg;
        end 
    end

    always_comb begin : M_AXIS_TLAST_processing 
        M_AXIS_TLAST = last_reg;
    end 


    generate
        if (USER_WIDTH > 0) begin

           (* srl_style = "register" *)logic [(USER_WIDTH-1):0] user_reg;

            always_ff @(posedge CLK) begin : user_reg_processing
                if (M_AXIS_TREADY) begin 
                    user_reg <= S_AXIS_TUSER;
                end else begin
                    user_reg <= user_reg;
                end
            end

            always_comb begin : M_AXIS_TUSER_processing 
                M_AXIS_TUSER = user_reg;
            end 

            // always_ff @(posedge CLK) begin : user_reg_processing
            //     if (M_AXIS_TREADY) begin 
            //         M_AXIS_TUSER <= S_AXIS_TUSER;
            //     end else begin
            //         M_AXIS_TUSER <= M_AXIS_TUSER;
            //     end
            // end


        end 

    endgenerate

endmodule : axis_register_reduced 