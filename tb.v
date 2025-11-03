`timescale 1ns/10ps
`define CYCLE      8.0  
`define SDFFILE    "./LASER_syn.sdf"
`define MAX_CYCLE_PER_PATTERN  500
//`define USECOLOR 
`define P2

module testfixture();

parameter PAT_NUMBER = 1;
parameter PIXELS_PER_PAT = 40;
parameter IMG_SIZE = 16;
parameter PAT_STR_LEN = 32;

localparam [7:0] CHAR_MINUS    = "-";
localparam [7:0] CHAR_STAR     = "*";
localparam [7:0] CHAR_LOWER_X  = "x";
localparam [7:0] CHAR_UPPER_X  = "X";
localparam [7:0] CHAR_PLUS     = "+";

function integer pixel_index;
    input integer pat_idx;
    input integer pix_idx;
    integer limited_pix;
    integer limited_pat;
begin
    limited_pix = pix_idx;
    if (limited_pix < 0)
        limited_pix = 0;
    else if (limited_pix >= PIXELS_PER_PAT)
        limited_pix = PIXELS_PER_PAT - 1;

    limited_pat = pat_idx;
    if (limited_pat < 0)
        limited_pat = 0;
    else if (limited_pat >= PAT_NUMBER)
        limited_pat = PAT_NUMBER - 1;

    pixel_index = limited_pat * PIXELS_PER_PAT + limited_pix;
end
endfunction

integer fd;

reg CLK;
reg RST;
wire [3:0] X;
wire [3:0] Y;
wire [3:0] C1X;
wire [3:0] C1Y;
wire [3:0] C2X;
wire [3:0] C2Y;
wire DONE;

LASER u_LASER(
.CLK(CLK),
.RST(RST),
.X(X),
.Y(Y),
.C1X(C1X),
.C1Y(C1Y),
.C2X(C2X),
.C2Y(C2Y),
.DONE(DONE));

`ifdef SDF
    initial $sdf_annotate(`SDFFILE, u_LASER);
`endif

always begin
    #(`CYCLE/2) CLK = ~CLK;
end

parameter ST_RESET = 0;
parameter ST_PATTERN = 1;
parameter ST_RUN = 2;
parameter ST_RETURN = 3;

reg [1:0] state;
reg [1:0] rst_count;
reg [5:0] pixel_count;
integer pat_n;
reg [30:0] cycle_pat;
reg [30:0] cycle_total;

integer i;
integer j;
integer items_read;
integer pixel_slot;

integer optmax [0:PAT_NUMBER-1];
integer PX [0:PAT_NUMBER*PIXELS_PER_PAT-1];
integer PY [0:PAT_NUMBER*PIXELS_PER_PAT-1];
integer RET_C1X [0:PAT_NUMBER-1];
integer RET_C1Y [0:PAT_NUMBER-1];
integer RET_C2X [0:PAT_NUMBER-1];
integer RET_C2Y [0:PAT_NUMBER-1];
reg [PAT_STR_LEN*8-1:0] pattern_files [0:PAT_NUMBER-1];

integer cover_sum;
integer total_cover_sum;
integer optimum_sum;
integer d1;
integer d2;
integer wait_done;

reg [7:0] img_mem [0:IMG_SIZE*IMG_SIZE-1];

wire [31:0] current_px_value;
wire [31:0] current_py_value;

assign current_px_value = PX[pixel_index(pat_n, pixel_count)];
assign current_py_value = PY[pixel_index(pat_n, pixel_count)];
assign X = current_px_value[3:0];
assign Y = current_py_value[3:0];

initial begin
    CLK = 1'b0;
    RST = 1'b0;
    state = ST_RESET;
    rst_count = 2'b00;
    pixel_count = 6'b0;
    pat_n = 0;
    cycle_pat = 0;
    cycle_total = 0;
    wait_done = 0;
    total_cover_sum = 0;
    optimum_sum = 0;
end

initial begin
`ifdef P2
    pattern_files[0] = "img2.pattern";
`elsif P3
    pattern_files[0] = "img3.pattern";
`elsif P4
    pattern_files[0] = "img4.pattern";
`elsif P5
    pattern_files[0] = "img5.pattern";
`elsif P6
    pattern_files[0] = "img6.pattern";
`else
    pattern_files[0] = "img1.pattern";
`endif

    for (i = 0; i < PAT_NUMBER; i = i + 1) begin
        optmax[i] = 0;
        RET_C1X[i] = 0;
        RET_C1Y[i] = 0;
        RET_C2X[i] = 0;
        RET_C2Y[i] = 0;

        for (j = 0; j < PIXELS_PER_PAT; j = j + 1) begin
            pixel_slot = i * PIXELS_PER_PAT + j;
            PX[pixel_slot] = 0;
            PY[pixel_slot] = 0;
        end

        fd = $fopen(pattern_files[i], "r");
        if (fd == 0) begin
            $display("Failed open %s", pattern_files[i]);
            $finish;
        end

        items_read = $fscanf(fd, "optimum=%d\n", optmax[i]);
        if (items_read != 1) begin
            $display("Pattern %0d header format error", i + 1);
            $finish;
        end

        for (j = 0; j < PIXELS_PER_PAT; j = j + 1) begin
            pixel_slot = i * PIXELS_PER_PAT + j;
            items_read = $fscanf(fd, "%d %d\n", PX[pixel_slot], PY[pixel_slot]);
            if (items_read != 2) begin
                $display("Pattern %0d data format error at entry %0d", i + 1, j);
                $finish;
            end
        end

        $fclose(fd);
    end
end

always @(posedge CLK) begin
    cycle_total <= cycle_total + 1;
end

always @(posedge CLK) begin
    case (state)
        ST_RESET: begin
            if (rst_count == 2) begin
                #1 RST <= 1'b0;
                rst_count <= 0;
                state <= ST_PATTERN;
            end else begin
                #1 RST <= 1'b1;
                rst_count <= rst_count + 1;
                pixel_count <= 0;
                wait_done <= 0;
            end
        end
        ST_PATTERN: begin
            if (DONE == 0) begin
                if (pixel_count < PIXELS_PER_PAT) begin
                    #1;
                    pixel_count <= pixel_count + 1;
                end else begin
                    state <= ST_RUN;
                    cycle_pat <= 0;
                end
            end else begin
                if (pixel_count == 0) begin
                    if (DONE === 1'bx) begin
                        $display("\n%10t , ERROR, DONE is in unknown state. Simlation terminated\n", $time);
                        $finish;
                    end else begin
                        #1;
                        $display("%10t , please pull down signal DONE", $time);
                        wait_done <= wait_done + 1;
                        if (wait_done > 10) begin
                            $display("\n%t , ERROR, please pull down signal DONE. Simlation terminated\n", $time);
                            $finish;
                        end
                    end
                end else begin
                    $display("\n%10t, ERROR, received DONE while send pattern, %s %3d pixel. Simlation terminated\n",
                             $time, pattern_files[pat_n], pixel_count);
                    $finish;
                end
            end
        end
        ST_RUN: begin
            if (DONE == 0) begin
                cycle_pat <= cycle_pat + 1;
                if (cycle_pat > `MAX_CYCLE_PER_PATTERN) begin
                    $display("== PATTERN %s", pattern_files[pat_n]);
                    $display("-- Max cycle pre pattern reached, force output result C1(%2d,%2d),C2(%2d,%2d)",
                             C1X, C1Y, C2X, C2Y);
                    count_cover(C1X, C1Y, C2X, C2Y, cover_sum, total_cover_sum, optimum_sum);
                    if (PAT_NUMBER == 1) begin
                        draw_img(C1X, C1Y, C2X, C2Y, pat_n);
                    end
                    RET_C1X[pat_n] <= C1X;
                    RET_C1Y[pat_n] <= C1Y;
                    RET_C2X[pat_n] <= C2X;
                    RET_C2Y[pat_n] <= C2Y;
                    if (pat_n < PAT_NUMBER - 1) begin
                        pat_n <= pat_n + 1;
                        pixel_count <= 0;
                        rst_count <= 0;
                        state <= ST_RESET;
                    end else begin
                        $display ("");
                        $display ("*******************************");
                        $display ("**   Finish Simulation       **");
                        $display ("**   RUN CYCLE = %10d  **", cycle_total);
                        $display ("**   Cover total = %3d/%3d   **", total_cover_sum, optimum_sum);
                        $display ("*******************************");
                        $finish;
                    end
                end
            end else begin
                $display("== PATTERN %s", pattern_files[pat_n]);
                $display("---- Used Cycle: %10d", cycle_pat);
                $display("---- Get Return: C1(%2d,%2d),C2(%2d,%2d)", C1X, C1Y, C2X, C2Y);
                count_cover(C1X, C1Y, C2X, C2Y, cover_sum, total_cover_sum, optimum_sum);
                if (PAT_NUMBER == 1) begin
                    draw_img(C1X, C1Y, C2X, C2Y, pat_n);
                end
                RET_C1X[pat_n] <= C1X;
                RET_C1Y[pat_n] <= C1Y;
                RET_C2X[pat_n] <= C2X;
                RET_C2Y[pat_n] <= C2Y;

                if (pat_n < PAT_NUMBER - 1) begin
                    pat_n <= pat_n + 1;
                    pixel_count <= 0;
                    state <= ST_PATTERN;
                end else begin
                    $display ("");
                    $display ("*******************************");
                    $display ("**   Finish Simulation       **");
                    $display ("**   RUN CYCLE = %10d  **", cycle_total);
                    $display ("**   Cover total = %3d/%3d   **", total_cover_sum, optimum_sum);
                    $display ("*******************************");
                    $finish;
                end
            end
        end
        default: begin
        end
    endcase
end

initial begin
    $display("*******************************");
    $display("** Simulation Start          **");
    $display("*******************************");
end

initial begin
    $dumpfile("laser.vcd");
    $dumpvars();
end

task count_cover;
    input [3:0] C1X;
    input [3:0] C1Y;
    input [3:0] C2X;
    input [3:0] C2Y;
    output integer cover_sum;
    inout integer total_cover_sum;
    inout integer optimum_sum;
    integer sample_idx;
    integer px_value;
    integer py_value;
    integer c1x_int;
    integer c1y_int;
    integer c2x_int;
    integer c2y_int;
begin
    cover_sum = 0;
    c1x_int = C1X;
    c1y_int = C1Y;
    c2x_int = C2X;
    c2y_int = C2Y;
    for (i = 0; i < PIXELS_PER_PAT; i = i + 1) begin
        sample_idx = pixel_index(pat_n, i);
        px_value = PX[sample_idx];
        py_value = PY[sample_idx];

        if ((^C1X === 1'bx) || (^C1Y === 1'bx)) begin
            d1 = 100;
        end else begin
            d1 = (c1x_int - px_value) * (c1x_int - px_value) +
                 (c1y_int - py_value) * (c1y_int - py_value);
        end

        if ((^C2X === 1'bx) || (^C2Y === 1'bx)) begin
            d2 = 100;
        end else begin
            d2 = (c2x_int - px_value) * (c2x_int - px_value) +
                 (c2y_int - py_value) * (c2y_int - py_value);
        end

        if ((d1 <= 16) || (d2 <= 16)) begin
            cover_sum = cover_sum + 1;
        end
    end
    total_cover_sum = total_cover_sum + cover_sum;
    optimum_sum = optimum_sum + optmax[pat_n];
    $display("---- cover = %3d, optimum = %3d", cover_sum, optmax[pat_n]);
end
endtask

task draw_img;
    input [3:0] C1X;
    input [3:0] C1Y;
    input [3:0] C2X;
    input [3:0] C2Y;
    input integer pat_idx;
    integer img_idx;
    integer px_value;
    integer py_value;
    integer c1x_int;
    integer c1y_int;
    integer c2x_int;
    integer c2y_int;
begin
    c1x_int = C1X;
    c1y_int = C1Y;
    c2x_int = C2X;
    c2y_int = C2Y;

    for (j = 0; j < IMG_SIZE; j = j + 1) begin
        for (i = 0; i < IMG_SIZE; i = i + 1) begin
            img_idx = i * IMG_SIZE + j;
            img_mem[img_idx] = CHAR_MINUS;
        end
    end

    if ((c1x_int < IMG_SIZE) && (c1y_int < IMG_SIZE)) begin
        img_mem[c1x_int * IMG_SIZE + c1y_int] = CHAR_STAR;
    end
    if ((c2x_int < IMG_SIZE) && (c2y_int < IMG_SIZE)) begin
        img_mem[c2x_int * IMG_SIZE + c2y_int] = CHAR_STAR;
    end

    for (i = 0; i < PIXELS_PER_PAT; i = i + 1) begin
        px_value = PX[pixel_index(pat_idx, i)];
        py_value = PY[pixel_index(pat_idx, i)];

        if ((^C1X === 1'bx) || (^C1Y === 1'bx)) begin
            d1 = 100;
        end else begin
            d1 = (c1x_int - px_value) * (c1x_int - px_value) +
                 (c1y_int - py_value) * (c1y_int - py_value);
        end

        if ((^C2X === 1'bx) || (^C2Y === 1'bx)) begin
            d2 = 100;
        end else begin
            d2 = (c2x_int - px_value) * (c2x_int - px_value) +
                 (c2y_int - py_value) * (c2y_int - py_value);
        end

        if ((px_value < IMG_SIZE) && (py_value < IMG_SIZE)) begin
            img_idx = px_value * IMG_SIZE + py_value;
            if ((d1 <= 16) || (d2 <= 16)) begin
                img_mem[img_idx] = CHAR_LOWER_X;
                if ((px_value == c1x_int) && (py_value == c1y_int)) begin
                    img_mem[img_idx] = CHAR_UPPER_X;
                end
                if ((px_value == c2x_int) && (py_value == c2y_int)) begin
                    img_mem[img_idx] = CHAR_UPPER_X;
                end
            end else begin
                img_mem[img_idx] = CHAR_PLUS;
            end
        end
    end

    $display("   0 1 2 3 4 5 6 7 8 9 a b c d e f");
    for (j = 0; j < IMG_SIZE; j = j + 1) begin
        $write(" %1x", j[3:0]);
        for (i = 0; i < IMG_SIZE; i = i + 1) begin
            img_idx = i * IMG_SIZE + j;
`ifdef USECOLOR
            case (img_mem[img_idx])
                CHAR_PLUS: begin
                    $write("%c[1;34m", 27);
                    $write("%s", {" ", img_mem[img_idx]});
                    $write("%c[0m", 27);
                end
                CHAR_LOWER_X: begin
                    $write("%c[1;31m", 27);
                    $write("%s", {" ", img_mem[img_idx]});
                    $write("%c[0m", 27);
                end
                CHAR_STAR,
                CHAR_UPPER_X: begin
                    $write("%c[1;32m", 27);
                    $write("%s", {" ", img_mem[img_idx]});
                    $write("%c[0m", 27);
                end
                default: begin
                    $write("%s", {" ", img_mem[img_idx]});
                end
            endcase
`else
            $write("%s", {" ", img_mem[img_idx]});
`endif
        end
        $write("\n");
    end
end
endtask

endmodule