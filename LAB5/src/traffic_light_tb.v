`timescale 1ns/1ps

module traffic_light_tb;
    // Test Signals
    reg clk = 0;
    reg reset = 1;
    reg sensor_north = 0;
    reg sensor_east = 0;
    reg [7:0] config_time = 10;
    wire [2:0] light_ns, light_ew;

    // Instantiate Unit Under Test (UUT)
    traffic_light uut (
        .clk(clk), 
        .reset(reset), 
        .sensor_north(sensor_north), 
        .sensor_east(sensor_east), 
        .config_time(config_time), 
        .light_ns(light_ns), 
        .light_ew(light_ew)
    ); //

    // Clock Generation
    // 10ns Period (100 MHz).
    // Simulation is done at a relaxed speed.
    always #5 clk = ~clk; //

    initial begin
        // Waveform setup
        $dumpfile("traffic.vcd"); 
        $dumpvars;

        // 1. Initialize
        #20 reset = 0;

        // 2. Test "Adaptive" Behavior
        // Activate North Sensor. The internal logic should add +20 to the timer.
        // If the critical path logic is working, the light will stay green longer.
        #100 sensor_north = 1; 

        // 3. Activate Both Sensors. Logic should revert to 'config_time'.
        #200 sensor_east = 1;

        #200 $finish;
    end
endmodule
