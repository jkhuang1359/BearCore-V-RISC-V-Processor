`timescale 1ns/1ps

module test_clint_periodic;
    reg clk;
    reg rst_n;
    reg bus_en;
    reg bus_we;
    reg [31:0] bus_addr;
    reg [31:0] bus_wdata;
    wire [31:0] bus_rdata;
    wire bus_ready;
    wire timer_irq;
    wire software_irq;
    
    // 实例化CLINT
    clint u_clint (
        .clk(clk),
        .rst_n(rst_n),
        .bus_en(bus_en),
        .bus_we(bus_we),
        .bus_addr(bus_addr),
        .bus_wdata(bus_wdata),
        .bus_rdata(bus_rdata),
        .bus_ready(bus_ready),
        .timer_irq_o(timer_irq),
        .software_irq_o(software_irq),
        .irq_enable(1'b1),
        .timer_mode(2'b00)  // 周期性模式
    );

    // 时钟生成
    always #5 clk = ~clk;
    
    // 测试任务：写入寄存器
    task write_reg;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            bus_en = 1'b1;
            bus_we = 1'b1;
            bus_addr = addr;
            bus_wdata = data;
            @(posedge clk);
            while (!bus_ready) @(posedge clk);
            bus_en = 1'b0;
            bus_we = 1'b0;
            #10;
            $display("[%0t] 写入寄存器 0x%08h = 0x%08h", $time, addr, data);
        end
    endtask
    
    // 测试任务：读取寄存器
    task read_reg;
        input [31:0] addr;
        output [31:0] data;
        begin
            @(posedge clk);
            bus_en = 1'b1;
            bus_we = 1'b0;
            bus_addr = addr;
            @(posedge clk);
            while (!bus_ready) @(posedge clk);
            data = bus_rdata;
            bus_en = 1'b0;
            #10;
            $display("[%0t] 读取寄存器 0x%08h = 0x%08h", $time, addr, data);
        end
    endtask
    
    // 监控定时器值
    task monitor_timer;
        integer i;
        begin
            for (i = 0; i < 10; i = i + 1) begin
                #100;  // 每100个时间单位检查一次
                begin
                    reg [31:0] mtime_low, mtime_high, mtimecmp_low;
                    read_reg(32'h0200BFF8, mtime_low);
                    read_reg(32'h0200BFFC, mtime_high);
                    read_reg(32'h02004000, mtimecmp_low);
                    $display("[%0t] MTIME=0x%08h_%08h, MTIMECMP低32位=0x%08h, timer_irq=%b", 
                             $time, mtime_high, mtime_low, mtimecmp_low, timer_irq);
                end
            end
        end
    endtask
    
    // 监视中断信号
    always @(posedge timer_irq) begin
        $display("[%0t] ⏰ 定时器中断触发!", $time);
    end
    
    always @(posedge software_irq) begin
        $display("[%0t] 🖥️  软件中断触发!", $time);
    end    
    
    initial begin
        $dumpfile("clint_periodic_test.vcd");
        $dumpvars(0, test_clint_periodic);
        
        // 初始化
        clk = 0;
        rst_n = 0;
        bus_en = 0;
        bus_we = 0;
        bus_addr = 0;
        bus_wdata = 0;
        
        // 復位
        #20 rst_n = 1;
        
        $display("=== CLINT 周期性模式測試 ===");
        
        // 測試周期性定時器中斷
        $display("\n測試：周期性定時器中斷");
        
        // 設置定時器比較值為當前值+20
        begin
            reg [31:0] current_mtime;
            read_reg(32'h0200BFF8, current_mtime);
            write_reg(32'h02004000, current_mtime + 20);
            $display("  初始設置 MTIMECMP = 當前值 + 20 = %0d", current_mtime + 20);
        end
        
        // 等待第一次中斷
        $display("  等待第一次中斷...");
        wait(timer_irq);
        $display("  ✅ 第一次中斷觸發");
        
        // 檢查 MTIMECMP 是否被更新為 mtime + 1000
        begin
            reg [31:0] mtime_low, mtimecmp_low;
            read_reg(32'h0200BFF8, mtime_low);
            read_reg(32'h02004000, mtimecmp_low);
            $display("  中斷時 MTIME = %0d, MTIMECMP 更新為 = %0d", mtime_low, mtimecmp_low);
            
            if (mtimecmp_low == mtime_low + 1000) 
                $display("  ✅ 周期性模式工作正常，MTIMECMP 更新為 MTIME + 1000");
            else
                $display("  ❌ MTIMECMP 更新錯誤，期望 %0d，得到 %0d", mtime_low + 1000, mtimecmp_low);
        end
        
        // 等待第二次中斷
        $display("\n  等待第二次中斷（約1000週期後）...");
        
        // 清除中斷標誌
        @(negedge timer_irq);
        
        // 設置計數器來等待第二次中斷
        begin
            integer wait_count = 0;
            integer max_wait = 1200;  // 稍多於1000
            
            while (!timer_irq && wait_count < max_wait) begin
                #100;  // 每100個時間單位檢查一次
                wait_count = wait_count + 1;
            end
            
            if (timer_irq) begin
                $display("  ✅ 第二次周期性中斷觸發（等待 %0d 個時間單位）", wait_count * 100);
            end else begin
                $display("  ❌ 第二次中斷未在預期時間內觸發");
            end
        end
        
        $display("\n=== 周期性模式測試完成 ===");
        
        #100 $finish;
    end
    
    // 監視中斷信號
    always @(posedge timer_irq) begin
        $display("[%0t] ⏰ 定時器中斷觸發（第%0d次）", $time, $time/1000 + 1);
    end
    
endmodule
