interface nonlinear_If(input bit clk,rst);
    typedef enum logic [3:0] {softmax,sigmoid,tanh,relu,pooling,average_pooling} operation; 
    operation op;
    logic           ready;
    logic           valid;
    logic   [3:0]   bubble;
    logic   [1:0]   continuity;
    logic   [9:0]   din_length;
    logic   [15:0]  din_addr;
    logic   [3:0]   win_length;
    logic   [5:0]   win_addr;
    logic   [15:0]  dout_addr;
endinterface //nonlinear_
module NonLinear_ctr(nonlinear_If If);
    //register define
    reg   [3:0]     reg_operation;
    reg   [1:0]     reg_continuity;
    reg   [9:0]     reg_din_length;
    reg   [15:0]    reg_din_addr;
    reg   [15:0]    reg_din_addr_start;
    reg   [3:0]     reg_win_length;
    reg   [5:0]     reg_win_addr;
    reg   [15:0]    reg_dout_addr;
    reg   [3:0]     reg_bubble_now;
    reg   [3:0]     reg_bubble_next;
    reg             reg_flag_load;
    reg   [3:0]     reg_load_cnt;
    reg   [9:0]     reg_exec_cnt;
    reg             reg_flag_pingpong;
    reg   [3:0]     reg_operation_now;    
    reg   [3:0]     reg_operation_next;    
    reg   [1:0]     reg_continuity_cnt;
    reg     [1:0]   reg_ln_cnt;
    reg             reg_flag_exec;
    //wire for register
    wire            wire_flag_exec;
    wire    [1:0]   wire_ln_cnt;
    wire    [15:0]  wire_din_addr_start;
    wire    [1:0]   wire_continuity_cnt;
    wire            wire_flag_pingpong;
    wire    [9:0]   wire_exec_cnt;
    wire            wire_flag_load;
    wire    [3:0]   wire_load_cnt;
    wire    [3:0]   wire_bubble_cnt;
    wire    [3:0]   wire_bubble_now;
    wire    [3:0]   wire_bubble_next;
    wire    [1:0]   wire_continuity;
    wire    [9:0]   wire_din_length;
    wire    [15:0]  wire_din_addr;
    wire    [3:0]   wire_win_length;
    wire    [5:0]   wire_win_addr;
    wire    [15:0]  wire_dout_addr;

    //wire for signal 
    wire            load_over;
    wire            exec_over;
    wire            exp1_over;
    wire            ln_over;
    wire            exp2_over;
    //state define for finite state machine 
    typedef enum logic [2:0] {idle,load,exec,exp1,ln,exp2}State;
    State           state,next;
    
    //Finite State Machine(AKA FSM)
    always_ff @(posedge If.clk)begin
        if(If.rst)
            state=idle;
        else 
            state=next;
    end
    always_comb begin
        next=State;
        unique case(state)
            idle:if(If.valid) next=load;
            load:begin
                if(load_over)begin
                    if(reg_operation==nonlinear_If.softmax)
                        next=exp1;
                    else 
                        next=exec;
                end
            end
            exec:if(exec_over) next=idle;
            exp1:if(exp1_over) next=ln;
            ln:if(ln_over) next=ln;
            exp2:if(exp2_over) next=idle;
        endcase
    end
    always_comb begin
        wire_din_addr_start=reg_din_addr_start;
        wire_continuity=reg_continuity;
        wire_din_length=reg_din_length;
        wire_dout_addr=reg_dout_addr;
        wire_win_addr=reg_win_addr;
        wire_win_length=reg_win_length;
        If.ready=0;
        wire_flag_load=0;
        wire_load_over=0;
        wire_operation_now=reg_operation_now;
        wire_flag_pingpong=reg_flag_pingpong;
        wire_bubble_cnt=0;
        unique case(state)
            idle:begin
                If.ready=1;
                if(If.valid)begin
                    wire_din_addr_start=If.din_addr;
                    wire_continuity=If.continuity;
                    wire_din_length=If.din_length;
                    wire_dout_addr=If.dout_addr;
                    wire_win_addr=If.win_addr;
                    wire_win_length=If.win_length;
                    wire_bubble_next=If.bubble;
                    wire_bubble_now=0;
                    wire_operation_next=If.operation;
                end 
            end
            load:begin
                if((reg_load_cnt==reg_bubble_now)|(reg_load_cnt==reg_win_length))begin
                    if(reg_flag_load==1)begin
                        wire_load_over=1;
                        wire_operation_now=reg_operation_next;
                        wire_flag_pingpong=~reg_flag_pingpong;
                    end
                    else 
                        wire_flag_load=1;
                end
                wire_win_addr=reg_win_addr+1;
                wire_load_cnt=reg_load_cnt+1;
            end
            exp1:
            exp2:
            exec:begin
                wire_bubble_now=reg_bubble_next;
                wire_din_addr=reg_din_addr_start+reg_exec_cnt;
                if(reg_exec_cnt==reg_din_length) begin 
                    reg_exec_cnt=0;
                    if(reg_continuity_cnt==reg_continuity)begin
                        wire_flag_exec=1;
                        wire_continuity_cnt=0;
                    end
                    else 
                        wire_continuity_cnt=reg_continuity_cnt+1;
                end 
                if(reg_flag_exec==1)begin
                    if(state==exec)
                        exec_over=1;
                    else if(state==exp2)
                        exp2_over==1;
                    else begin
                        if(reg_bubble_cnt==reg_bubble_now)begin
                            wire_bubble_cnt=0;
                            exp1_over=1;
                        end
                        else 
                            wire_bubble_cnt==reg_bubble_cnt+1;
                    end
                end
            end
            ln:begin
                if(reg_ln_cnt==reg_continuity)begin
                    wire_ln_cnt=reg_continuity;
                    if(reg_bubble_cnt==reg_bubble_now)begin
                        ln_over=1;
                        wire_bubble_cnt=0;
                    end
                    else 
                        wire_bubble_cnt=reg_bubble_cnt+1;
                end
                else 
                    wire_ln_cnt=reg_ln_cnt+1;
            end
        endcase
    end
endmodule 