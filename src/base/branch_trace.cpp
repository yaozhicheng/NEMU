extern "C" {
    #include <common.h>
    #include <debug.h>
}

#ifdef CONFIG_ENABLE_BRANCH_TRACE

#include <thread>
#include <mutex>
#include <chrono>
#include <queue>
#include <map>
#include <fstream>
#include <cstdlib>
#include <string>

typedef struct {
    u_int64_t index;
    u_int64_t pc;
    u_int64_t target;
    u_int32_t taken;
    u_int32_t type;
} branch_trace;

std::queue<branch_trace> trace_queue;
std::mutex mtx, qmtx;
uint64_t __br_trace_index__ = 0;
bool branch_trace_dump_started = false;
std::thread task;

void branch_trace_dump(pid_t parent_id){
    u_int64_t flage = 0xbebebebebebebebe;
    std::fstream ofs("__all_branch.trace", std::ios::out|std::ios::binary);
    ofs.write((char *)&flage, sizeof(flage));
    ofs.write((char *)&flage, sizeof(flage));
    bool debug_log = std::getenv("BR_STD_LOG") != nullptr;
    while (true)
    {
        branch_trace t;
        qmtx.lock();
        if(trace_queue.empty()){
            qmtx.unlock();
            if(!branch_trace_dump_started)break;
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
            continue;
        }
        t = trace_queue.front();
        trace_queue.pop();
        ofs.write((char *)&t, sizeof(t));
        if(debug_log){
            printf("[%ld] PC: %lx => %lx taken: %d, type: %d\n", t.index, t.pc, t.target, t.taken, t.type);
        }
        qmtx.unlock();
    }
    flage = 0xedededededededed;
    ofs.write((char *)&flage, sizeof(flage));
    ofs.write((char *)&flage, sizeof(flage));
    ofs.flush();
    ofs.close();
}

extern "C" {
    void report_br_trace(uint64_t pc, uint64_t target, uint32_t taken, uint32_t type){
        assert(target > 0);
        // start dump thread
        mtx.lock();
        if (!branch_trace_dump_started){
            branch_trace_dump_started = true;
            task = std::thread(branch_trace_dump, getppid());
        }
        mtx.unlock();
        // send trace data to queue
        qmtx.lock();
        branch_trace t;
        t.index = __br_trace_index__;
        t.pc = pc;
        t.target = target;
        t.taken = taken;
        t.type = type;
        trace_queue.push(t);
        __br_trace_index__ += 1;
        qmtx.unlock();
    }
    void report_br_trace_join(){
        branch_trace_dump_started = false;
        task.join();
    }
}
#else
extern "C" {
    void report_br_trace(uint64_t pc, uint64_t target, uint32_t taken, uint32_t type){}
}
#endif
