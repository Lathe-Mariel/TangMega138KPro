// ============================================================
// TMDS Encoder (DVI 1.0 / HDMI)
// Reference: DVI 1.0 Specification Section 3.3.3
// ============================================================
module tmds_encoder (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] data,     // pixel data
    input  wire [1:0] ctrl,     // ctrl[1]=vsync ctrl[0]=hsync (during blanking)
    input  wire       de,       // data enable
    output reg  [9:0] tmds
);

// ── Step 1: XNOR/XOR select ────────────────────────────────
wire [8:0] q_m;
wire       use_xnor;

// Count ones in data
wire [3:0] data_ones;
assign data_ones = data[0]+data[1]+data[2]+data[3]+
                   data[4]+data[5]+data[6]+data[7];

assign use_xnor = (data_ones > 4'd4) || (data_ones == 4'd4 && data[0] == 1'b0);

assign q_m[0] = data[0];
assign q_m[1] = use_xnor ? ~(q_m[0] ^ data[1]) : (q_m[0] ^ data[1]);
assign q_m[2] = use_xnor ? ~(q_m[1] ^ data[2]) : (q_m[1] ^ data[2]);
assign q_m[3] = use_xnor ? ~(q_m[2] ^ data[3]) : (q_m[2] ^ data[3]);
assign q_m[4] = use_xnor ? ~(q_m[3] ^ data[4]) : (q_m[3] ^ data[4]);
assign q_m[5] = use_xnor ? ~(q_m[4] ^ data[5]) : (q_m[4] ^ data[5]);
assign q_m[6] = use_xnor ? ~(q_m[5] ^ data[6]) : (q_m[5] ^ data[6]);
assign q_m[7] = use_xnor ? ~(q_m[6] ^ data[7]) : (q_m[6] ^ data[7]);
assign q_m[8] = ~use_xnor;   // 0=XNOR, 1=XOR

// ── Step 2: DC balance ─────────────────────────────────────
reg signed [4:0] disparity;   // running disparity counter

// Count ones in q_m[7:0]
wire [3:0] qm_ones;
assign qm_ones = q_m[0]+q_m[1]+q_m[2]+q_m[3]+
                 q_m[4]+q_m[5]+q_m[6]+q_m[7];
wire signed [4:0] qm_ones_s  = {1'b0, qm_ones};
wire signed [4:0] qm_zeros_s = 5'd8 - qm_ones_s;
wire signed [4:0] diff = qm_ones_s - qm_zeros_s;  // ones - zeros

always @(posedge clk or posedge rst) begin
    if (rst) begin
        disparity <= 0;
        tmds      <= 10'b1101010100;   // control token 00
    end else if (!de) begin
        // Blanking: output control tokens
        disparity <= 0;
        case (ctrl)
            2'b00: tmds <= 10'b1101010100;
            2'b01: tmds <= 10'b0010101011;
            2'b10: tmds <= 10'b0101010100;
            2'b11: tmds <= 10'b1010101011;
        endcase
    end else begin
        // Data period
        if (disparity == 0 || diff == 0) begin
            if (q_m[8]) begin
                tmds      <= {2'b01, q_m[7:0]};
                disparity <= disparity + diff;
            end else begin
                tmds      <= {2'b10, ~q_m[7:0]};
                disparity <= disparity - diff;
            end
        end else begin
            if ((disparity > 0 && diff > 0) || (disparity < 0 && diff < 0)) begin
                tmds      <= {1'b1, q_m[8], ~q_m[7:0]};
                disparity <= disparity + {3'b0, q_m[8], 1'b0} - diff;
            end else begin
                tmds      <= {1'b0, q_m[8], q_m[7:0]};
                disparity <= disparity - {3'b0, ~q_m[8], 1'b0} + diff;
            end
        end
    end
end

endmodule
