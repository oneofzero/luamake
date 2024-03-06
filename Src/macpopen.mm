#import <Foundation/Foundation.h>
#include <string>
int MacRunCmd(const char* cmd,std::string& sOutput) {
    @autoreleasepool {
        // 创建一个 NSTask 实例
        NSTask *task = [[NSTask alloc] init];
        // 设置要执行的命令
        [task setLaunchPath:@"/bin/zsh"];
        // 设置命令参数
        NSString *nsString = [NSString stringWithUTF8String:cmd];
        [task setArguments:@[@"-c", nsString]];
        
        // 创建管道用于读取子进程的输出
        NSPipe *pipe = [NSPipe pipe];
        // 将管道设置为任务的标准输出
        [task setStandardOutput:pipe];
        
        // 启动任务
        [task launch];
        
        // 获取管道的读取端
        NSFileHandle *fileHandle = [pipe fileHandleForReading];
        // 读取子进程输出的数据
        NSData *data = [fileHandle readDataToEndOfFile];
        // 将数据转换为字符串并输出
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        //NSLog(@"Task output:\n%@", output);
        
        // 等待任务结束
        [task waitUntilExit];
        
        // 获取任务的退出状态
        int status = [task terminationStatus];
        //NSLog(@"Task exit status: %d", status);
        sOutput = [output UTF8String];
        return status;
    }
   
}