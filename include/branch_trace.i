%module(directors="1") NemuBR

%apply unsigned long long {u_int64_t}
%apply unsigned int {u_uint32_t}
%apply unsigned short {u_uint16_t}
%apply unsigned char {u_uint8_t}

%apply unsigned long long {uint64_t}
%apply unsigned int {uint32_t}
%apply unsigned short {uint16_t}
%apply unsigned char {uint8_t}

%apply long long {i_int64_t}
%apply int {i_int32_t}
%apply short {i_int16_t}
%apply char {i_int8_t}

%apply long long {int64_t}
%apply int {int32_t}
%apply short {int16_t}
%apply char {int8_t}

%include std_string.i
%include std_map.i
%include std_vector.i

namespace std {
   %template(StringVector) vector<string>;
}

%{
#include "branch_trace.h"
%}

%include "branch_trace.h"

%pythoncode%{
# extended randomtrace
import random
import bisect

class RandomBPTTrace(object):
    def __init__(self) -> None:
        self.branch_type = [
                   "C.J",
                   "C.JR",
                   "C.CALL",
                   "C.RET",
                   "C.JALR",
                   "P.JAL",
                   "P.CALL",
                   "P.RET",
                   "*.CBR",
                   "I.JAL",
                   "I.JALR",
                   "I.CALL",
                   "I.RET",
        ]
        self.branch_list = []
    def gen(self, start_address=None, pc_range_size=None, br_count=None, max_repeat=100, br_max_count=1000000, max_yield=1e9, seed=None, address_width=39, branch_type=None, min_gap=0x100):
        max_address = 2 ** address_width - 1
        if seed is not None:
            random.seed(seed)
        if start_address is None:
            start_address = random.randint(0, max_address - min_gap)
        if pc_range_size is None:
            pc_range_size = max(min_gap, random.randint(start_address + min_gap, max_address) - start_address)
        if br_count is None:
            br_count = int(max(1, random.randint(1, br_max_count/2) % (pc_range_size/2)))
        br_list = []
        pc_list = []
        tg_list = []
        rp_list = []
        br_types_cp = []
        br_types_nm = []
        ins_size = 4
        br_types = branch_type if branch_type is not None else self.branch_type
        for  br in br_types:
            if br.startswith("C."):
                br_types_cp.append(br)
                ins_size = 2
            else:
                br_types_nm.append(br)
        for pc in sorted(set([pc - (pc%ins_size) for pc in random.sample(range(start_address, start_address + pc_range_size), br_count)])):
            pc_list.append(pc)
            rp_list.append(max_repeat)
            tg_list.append(random.randint(start_address, start_address + pc_range_size))
            if ins_size == 2:
                if pc % 4 != 0:
                    br_list.append(random.choice(br_types_cp)) # must be compress
                else:
                    br_list.append(random.choice(br_types))    # can be compress or normal
            else:
                br_list.append(random.choice(br_types_nm))     # must be normal
        pc_index = 0
        pc_index_max = len(pc_list)
        rt_yeild = 0
        while True:
            if pc_index >= pc_index_max:
                break
            repeat = rp_list[pc_index]
            if repeat <= 0:
                pc_index += 1
                continue
            rp_list[pc_index] -= 1
            br_t = br_list[pc_index]
            pc = pc_list[pc_index]
            taken = True
            target = tg_list[pc_index]
            if random.randint(0, 100) < random.randint(0, 100):
                target = random.randint(start_address, start_address + pc_range_size)
            if br_t == "*.CBR":
                if random.randint(0, 100) < random.randint(0, 100):
                    taken = False
            if taken:
                if target > pc:
                    pc_index = bisect.bisect_left(pc_list[pc_index:], target) + pc_index
                else:
                    pc_index = bisect.bisect_left(pc_list[:pc_index], target)
            else:
                pc_index += 1
            yield {"pc": pc, "index": rt_yeild, "target": target, "taken": taken, "type": br_t}
            rt_yeild += 1
            if rt_yeild > max_yield:
                break
        return None

%}
