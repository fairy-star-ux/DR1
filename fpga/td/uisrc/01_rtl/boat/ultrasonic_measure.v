module ultrasonic_measure #(
    parameter integer CLK_HZ         = 100_000_000,
    parameter integer OBSTACLE_CM    = 50,
    parameter integer TRIG_PERIOD_MS = 60
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       echo,
    output reg        trig,
    output reg [15:0] distance_cm,
    output reg        valid,
    output reg        obstacle
);

    localparam integer TRIG_INTERVAL_CYCLES = (CLK_HZ / 1000) * TRIG_PERIOD_MS;
    localparam integer TRIG_HIGH_CYCLES     = CLK_HZ / 100_000;
    localparam integer ECHO_TIMEOUT_CYCLES  = CLK_HZ / 20;
    localparam integer CYCLES_PER_CM        = (CLK_HZ * 2) / 34_300;

    localparam [2:0] ST_IDLE      = 3'd0;
    localparam [2:0] ST_TRIG      = 3'd1;
    localparam [2:0] ST_WAIT_RISE = 3'd2;
    localparam [2:0] ST_MEASURE   = 3'd3;

    reg [2:0]  state;
    reg [31:0] interval_count;
    reg [31:0] state_count;
    reg [31:0] echo_count;
    reg [13:0] cm_cycle_count;
    reg [8:0]  measured_cm;
    reg        echo_meta;
    reg        echo_sync;

    always @(posedge clk) begin
        if (!rst_n) begin
            state          <= ST_IDLE;
            interval_count <= 32'd0;
            state_count    <= 32'd0;
            echo_count     <= 32'd0;
            cm_cycle_count <= 14'd0;
            measured_cm    <= 9'd0;
            echo_meta      <= 1'b0;
            echo_sync      <= 1'b0;
            trig           <= 1'b0;
            distance_cm    <= 16'd0;
            valid          <= 1'b0;
            obstacle       <= 1'b0;
        end else begin
            echo_meta <= echo;
            echo_sync <= echo_meta;

            case (state)
                ST_IDLE: begin
                    trig        <= 1'b0;
                    valid       <= 1'b0;
                    state_count <= 32'd0;

                    if (interval_count >= TRIG_INTERVAL_CYCLES - 1) begin
                        interval_count <= 32'd0;
                        state_count    <= 32'd0;
                        trig           <= 1'b1;
                        state          <= ST_TRIG;
                    end else begin
                        interval_count <= interval_count + 1'b1;
                    end
                end

                ST_TRIG: begin
                    trig <= 1'b1;

                    if (state_count >= TRIG_HIGH_CYCLES - 1) begin
                        trig        <= 1'b0;
                        state_count <= 32'd0;
                        state       <= ST_WAIT_RISE;
                    end else begin
                        state_count <= state_count + 1'b1;
                    end
                end

                ST_WAIT_RISE: begin
                    trig <= 1'b0;

                    if (echo_sync) begin
                        echo_count     <= 32'd0;
                        cm_cycle_count <= 14'd0;
                        measured_cm    <= 9'd0;
                        state_count    <= 32'd0;
                        state          <= ST_MEASURE;
                    end else if (state_count >= ECHO_TIMEOUT_CYCLES - 1) begin
                        distance_cm <= 16'd0;
                        valid       <= 1'b0;
                        obstacle    <= 1'b0;
                        state_count <= 32'd0;
                        state       <= ST_IDLE;
                    end else begin
                        state_count <= state_count + 1'b1;
                    end
                end

                ST_MEASURE: begin
                    if (echo_sync) begin
                        if (echo_count < ECHO_TIMEOUT_CYCLES) begin
                            echo_count <= echo_count + 1'b1;

                            if (cm_cycle_count >= CYCLES_PER_CM - 1) begin
                                cm_cycle_count <= 14'd0;
                                if (measured_cm < 9'd500) begin
                                    measured_cm <= measured_cm + 1'b1;
                                end
                            end else begin
                                cm_cycle_count <= cm_cycle_count + 1'b1;
                            end
                        end else begin
                            distance_cm <= 16'd0;
                            valid       <= 1'b0;
                            obstacle    <= 1'b0;
                            state       <= ST_IDLE;
                        end
                    end else begin
                        if (measured_cm == 0) begin
                            distance_cm <= 16'd1;
                        end else begin
                            distance_cm <= {7'd0, measured_cm};
                        end

                        valid    <= 1'b1;
                        obstacle <= (measured_cm <= OBSTACLE_CM);
                        state    <= ST_IDLE;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
