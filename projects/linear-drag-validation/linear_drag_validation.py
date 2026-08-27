"""线性阻力速度演化：NumPy 数值验证。"""

import matplotlib.pyplot as plt
import numpy as np

m = 0.20  # kg
b = 0.40  # kg/s
g = 10.0  # m/s^2
dt = 0.50  # s

t = np.arange(0.0, 3.0 + dt, dt)

# 根据模型参数计算终端速度和特征时间。
v_terminal = m * g / b
tau = m / b

# 把解析速度 v(t) 写成 NumPy 数组表达式。
v_exact = v_terminal * (1 - np.exp(-t / tau))

# 从离散速度采样估计 dv/dt。
a_num = np.gradient(v_exact, t)

# 直接由受力模型计算同一批时刻的加速度。
a_model = g - (b / m) * v_exact
error = a_num - a_model

print("columns: t (s), v_exact (m/s), a_num (m/s^2), a_model (m/s^2)")
print(np.column_stack((t[:4], v_exact[:4], a_num[:4], a_model[:4])))

# 输出首点、内部和末点误差。
print("first-point error:", error[0])
print("largest interior absolute error:", np.max(np.abs(error[1:-1])))
print("last-point error:", error[-1])

fig, axes = plt.subplots(2, 1, sharex=True, figsize=(7, 7))

axes[0].plot(t, v_exact, "o-", label="analytical velocity")
# 标明速度纵轴名称与单位。
axes[0].set_ylabel("velocity (m/s)")
axes[0].grid(True)
axes[0].legend()

axes[1].plot(t, a_model, "-", label="model acceleration")
axes[1].plot(t, a_num, "s--", label="numerical derivative")
# 标明时间横轴、加速度纵轴的名称与单位。
axes[1].set_xlabel("time (s)")
axes[1].set_ylabel("acceleration (m/s^2)")
axes[1].grid(True)
axes[1].legend()

plt.tight_layout()
plt.show()
