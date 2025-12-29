module test_timer_only;
    reg clk;
    reg rst_n;
    wire timer_irq;
    
    // 简化的定时器模块用于测试
    reg [63:0] mtime;
    reg [63:0] mtimecmp;
    reg irq_enable;
    
    // 定时器中断逻辑
    assign timer_irq = (mtime >= mtimecmp) && irq_enable;
    
    // 时钟生成
    always #5 clk = ~clk;
    
    initial begin
        $dumpfile("timer_only_test.vcd");
        $dumpvars(0, test_timer_only);
        
        // 初始化
        clk = 0;
        rst_n = 0;
        mtime = 64'b0;
        mtimecmp = 64'hFFFFFFFFFFFFFFFF;  // 默认不触发
        irq_enable = 1'b1;
        
        $display("=== 定时器逻辑单元测试 ===");
        
        // 复位
        #10 rst_n = 1;
        
        // 测试1：基本比较逻辑
        $display("\n测试1：基本比较逻辑");
        mtime = 64'd0;
        mtimecmp = 64'd10;
        
        #10;  // mtime=0
        $display("  mtime=%0d, mtimecmp=%0d, timer_irq=%b (期望: 0)", 
                 mtime, mtimecmp, timer_irq);
        
        mtime = 64'd10;
        #10;
        $display("  mtime=%0d, mtimecmp=%0d, timer_irq=%b (期望: 1)", 
                 mtime, mtimecmp, timer_irq);
        
        mtime = 64'd15;
        #10;
        $display("  mtime=%0d, mtimecmp=%0d, timer_irq=%b (期望: 1)", 
                 mtime, mtimecmp, timer_irq);
        
        // 测试2：中断使能控制
        $display("\n测试2：中断使能控制");
        irq_enable = 1'b0;
        #10;
        $display("  irq_enable=0, timer_irq=%b (期望: 0)", timer_irq);
        
        irq_enable = 1'b1;
        #10;
        $display("  irq_enable=1, timer_irq=%b (期望: 1)", timer_irq);
        
        // 测试3：64位比较
        $display("\n测试3：64位比较测试");
        mtime = 64'h0000_0000_0000_1000;
        mtimecmp = 64'h0000_0000_0000_0FFF;
        #10;
        $display("  mtime > mtimecmp, timer_irq=%b (期望: 1)", timer_irq);
        
        mtimecmp = 64'h0000_0000_0000_1000;
        #10;
        $display("  mtime = mtimecmp, timer_irq=%b (期望: 1)", timer_irq);
        
        mtimecmp = 64'h0000_0000_0000_1001;
        #10;
        $display("  mtime < mtimecmp, timer_irq=%b (期望: 0)", timer_irq);
        
        // 测试4：边界情况
        $display("\n测试4：边界情况");
        mtime = 64'hFFFFFFFFFFFFFFFE;
        mtimecmp = 64'hFFFFFFFFFFFFFFFF;
        #10;
        $display("  接近最大值: mtime < mtimecmp, timer_irq=%b (期望: 0)", timer_irq);
        
        mtime = 64'hFFFFFFFFFFFFFFFF;
        #10;
        $display("  最大值: mtime = mtimecmp, timer_irq=%b (期望: 1)", timer_irq);
        
        $display("\n=== 定时器逻辑测试完成 ===");
        
        #100 $finish;
    end
    
    // 定时器递增（模拟）
    always @(posedge clk) begin
        if (rst_n) begin
            mtime <= mtime + 1;
        end
    end
    
endmodule