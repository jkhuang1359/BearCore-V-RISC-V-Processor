`timescale 1ns/1ps

module alu_test;
    reg [31:0] a, b;
    reg [3:0] op;
    wire [31:0] result;
    wire zero;
    
    // 实例化ALU
    alu dut (
        .a(a),
        .b(b),
        .op(op),
        .result(result),
        .zero(zero)
    );
    
    integer errors = 0;
    integer total_tests = 0;
    
    initial begin
        $dumpfile("alu_test.vcd");
        $dumpvars(0, alu_test);
        
        // 测试加法
        a = 32'h00000005;
        b = 32'h00000003;
        op = 4'b0000;  // ADD
        #10;
        check_result(32'h00000008, "ADD");
        
        // 测试减法
        a = 32'h0000000A;
        b = 32'h00000003;
        op = 4'b0001;  // SUB
        #10;
        check_result(32'h00000007, "SUB");
        
        // 测试AND
        a = 32'hF0F0F0F0;
        b = 32'h0F0F0F0F;
        op = 4'b0010;  // AND
        #10;
        check_result(32'h00000000, "AND");
        
        // 测试OR
        a = 32'hF0F0F0F0;
        b = 32'h0F0F0F0F;
        op = 4'b0011;  // OR
        #10;
        check_result(32'hFFFFFFFF, "OR");
        
        // 测试XOR
        a = 32'hAAAAAAAA;
        b = 32'h55555555;
        op = 4'b0100;  // XOR
        #10;
        check_result(32'hFFFFFFFF, "XOR");
        
        // 测试SLT
        a = 32'h00000005;
        b = 32'h0000000A;
        op = 4'b0101;  // SLT
        #10;
        check_result(32'h00000001, "SLT (less)");
        
        a = 32'h0000000A;
        b = 32'h00000005;
        op = 4'b0101;  // SLT
        #10;
        check_result(32'h00000000, "SLT (greater)");
        
        // 测试SLL
        a = 32'h00000001;
        b = 32'h00000004;  // 移位4位
        op = 4'b0110;  // SLL
        #10;
        check_result(32'h00000010, "SLL");
        
        // 测试SRL
        a = 32'h80000000;
        b = 32'h00000004;  // 移位4位
        op = 4'b0111;  // SRL
        #10;
        check_result(32'h08000000, "SRL");
        
        // 测试SRA
        a = 32'h80000000;
        b = 32'h00000004;  // 移位4位
        op = 4'b1000;  // SRA
        #10;
        check_result(32'hF8000000, "SRA");
        
        // 汇总结果
        if (errors == 0) begin
            $display("✓ ALU所有测试通过! (%0d个测试)", total_tests);
        end else begin
            $display("✗ ALU测试失败: %0d个错误", errors);
        end
        
        $finish;
    end
    
    task check_result;
        input [31:0] expected;
        input [80:0] test_name;
        begin
            total_tests = total_tests + 1;
            if (result !== expected) begin
                $display("✗ %0s失败: 期望 0x%08h, 得到 0x%08h", 
                        test_name, expected, result);
                errors = errors + 1;
            end else begin
                $display("✓ %0s通过", test_name);
            end
        end
    endtask
    
endmodule
