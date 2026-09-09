"""AI 教学配图：指数减速示例，不作为学习者成果。"""

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


def main():
    # 给定运动模型；不把画图视为已验证该模型的受力来源。
    initial_speed = 6.0  # m/s
    tau = 3.0  # s
    time = np.linspace(0.0, 12.0, 401)
    speed = initial_speed * np.exp(-time / tau)
    samples = tau * np.arange(5)
    fig, ax = plt.subplots(figsize=(8, 4.5), constrained_layout=True)
    ax.plot(time, speed, color="#176b91", linewidth=2.5,
            label=r"$v(t)=v_0 e^{-t/\tau}$; $v_0=6$ m/s, $\tau=3$ s")
    ax.scatter(samples, initial_speed * np.exp(-samples / tau),
               color="#a64419", zorder=3, label=r"Equal intervals: $\Delta t=\tau$")
    ax.fill_between(time, speed, where=time <= tau, color="#176b91", alpha=0.15,
                    label=r"Area from $0$ to $\tau$: displacement (m)")
    ax.set(xlabel="Time t (s)", ylabel="Velocity v (m/s)",
           title="Exponential slowing: slope and accumulated area",
           xlim=(0, 12), ylim=(0, 6.5), xticks=samples)
    ax.grid(alpha=0.25)
    ax.legend(loc="upper right", fontsize=9)
    fig.savefig(Path(__file__).with_name("exponential-motion.png"), dpi=160)
    plt.close(fig)


if __name__ == "__main__":
    main()
