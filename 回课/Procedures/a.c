#include <stdio.h>

void target_function() {
    printf("Target function called!\n");
}

int main() {
    void (*func_ptr)() = target_function; // 函数指针
    func_ptr(); // 间接调用目标函数
    return 0;
}
