module ptb_follower_fsm #(
    parameter PTB_ACQ_WINDOW  = 16,
    parameter PTB_LOCK_THRESH = 14
)(
    input  wire clk,
    input  wire rst_n,

    input  wire ptb_follow_valid,
    input  wire ptb_oam_valid,

    input  wire ptbclk_started,
    input  wire [4:0] cnt_follow_received,
    input  wire [4:0] cnt_dlyrply_received,
    input  wire [4:0] ptb_synced_updates,

    output reg  ptbclk_start,
    output reg  calc_offset,
    output reg  calc_delay,
    output reg  copy_oam,
    output reg  info_oam,
    output reg  ptb_oam_delay_clear,
    output reg  ptb_locked,
    output reg  [1:0] state
);

    // State encoding
    localparam UNLOCKED    = 2'b00;
    localparam ACQUISITION = 2'b01;
    localparam LOCKED      = 2'b10;

    // Next-state logic
    reg [1:0] next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= UNLOCKED;
        else
            state <= next_state;
    end

    always @(*) begin
        next_state          = state;
        ptbclk_start        = 1'b0;
        calc_offset         = 1'b0;
        calc_delay          = 1'b0;
        copy_oam            = 1'b0;
        info_oam            = 1'b0;
        ptb_oam_delay_clear = 1'b0;
        ptb_locked          = 1'b0;

        case (state)

            UNLOCKED: begin
                if (ptb_oam_valid) begin
                    copy_oam     = 1'b1;
                    ptbclk_start = 1'b1;
                end

                if (ptb_follow_valid && ptbclk_started && (cnt_dlyrply_received >= 1)) begin
                    calc_offset = 1'b1;
                    calc_delay  = 1'b1;
                    next_state  = ACQUISITION;
                end
            end

            ACQUISITION: begin
                if (ptb_oam_valid)
                    ptb_oam_delay_clear = 1'b1;

                if (ptb_follow_valid && ptbclk_started && (cnt_dlyrply_received >= 1)) begin
                    calc_offset = 1'b1;
                    calc_delay  = 1'b1;
                end

                if (cnt_follow_received >= PTB_ACQ_WINDOW) begin
                    if (ptb_synced_updates >= PTB_LOCK_THRESH)
                        next_state = LOCKED;
                    else
                        next_state = UNLOCKED;
                end
            end

            LOCKED: begin
                ptb_locked = 1'b1;

                if (ptb_oam_valid)
                    info_oam = 1'b1;

                if (ptb_follow_valid && ptbclk_started && (cnt_dlyrply_received >= 1)) begin
                    calc_offset = 1'b1;
                    calc_delay  = 1'b1;
                    next_state  = ACQUISITION;
                end
            end

            default: begin
                next_state = UNLOCKED;
            end
        endcase
    end
endmodule