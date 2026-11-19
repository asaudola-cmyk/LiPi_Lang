import time

def fib(n):
    if n <= 1:
        return n
    return fib(n - 1) + fib(n - 2)

t0 = time.perf_counter()
res = fib(35)
t1 = time.perf_counter()

elapsed_ms = (t1 - t0) * 1000.0
print("Python Fibonacci (35) Complete!")
print(f"Sum: {res}")
print(f"Elapsed Time: {elapsed_ms:.2f} ms")
