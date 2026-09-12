# MoonRecur 0.2.1 维护验证记录

## 验证范围

维护基线是公开仓库原 main 提交 `aa2f5a3`（0.2.0）。本次验证针对纯日期
RRULE 子集、RDATE/EXDATE 集合以及全天忙闲区间，不包含时区和真实计时器。
数据是固定种子 5545 生成的合成输入，不含真实用户日历。

| 指标 | 原提交 aa2f5a3 | 维护后 | 证据 |
| --- | ---: | ---: | --- |
| 原有及新增 MoonBit 测试组 | 51 通过 | 66 通过 | `moon test` |
| 同一组 dateutil 对照 | 692/800，108 失败 | 800/800，0 失败 | `quality/dateutil-*.json` |
| 对照符合率 | 86.5% | 100% | 仅限这组测试，不是完整 RFC 认证 |
| 稀疏 DAILY 用例候选访问量 | 366001（逐日扫描路径推导） | 37（白盒计数断言） | `expand_wbtest.mbt` |
| 公历周期验证 | 无完整周期测试 | 146097 个日期 | `properties_test.mbt` |
| 区间占用模型验证 | 无此生成测试 | 200 组 × 90 天 | `properties_test.mbt` |
| 真实 CLI 进程验收 | 不作追溯计数 | 每目标 10 个 | `scripts/check_cli.py` |

800 个对照用例由四类频率各 160 个规则用例和 160 个例外集合用例组成。
窗口偏移、COUNT/UNTIL、间隔、负月日、跨年/月末/闰日、乱序重复 RDATE、
EXDATE 和较小 limit 都进入组合。日期序列逐项精确比较，不使用浮点容差。
800 个用例在不同后端重复执行，**不能据此宣称有 3200 个不同输入用例**；
146097 天也是一个性质测试中的日期数量，不是 146097 个独立测试组。

## 如何复现

```sh
python -m pip install -r scripts/requirements-test.txt
moon update
moon test --target wasm-gc --deny-warn
python scripts/compare_dateutil.py --target wasm-gc --report result.json
python scripts/check_cli.py --target wasm-gc
```

将 `wasm-gc` 替换为 `wasm`、`js` 或 `native` 可验证其他目标。native 需要 C
编译器。对照脚本临时生成 MoonBit 黑盒测试包，调用公开 API 后清理；若未实际
执行满 800 个测试，即便工具返回零也不判定成功。固定测试输入及期望输出摘要：
`cdbbefde348b3dd28fca37f8b2c5d7e6c9272f81e4a85f87f22b6c959a236224`。

旧版本对照可在独立 worktree 复现，不需要改动当前开发目录：

```sh
git worktree add --detach ../moonrecur-baseline aa2f5a3
cd ../moonrecur-baseline
moon update
cd ../moonrecur
python scripts/compare_dateutil.py --project-root ../moonrecur-baseline --report baseline.json
```

最后一条在旧版本上应返回非零，汇总为 692 通过、108 失败。旧版本汇总被保留
用于回归说明，不能误读成当前 CI 失败。

## 对标软件和边界

对标软件是 **python-dateutil 2.9.0.post0** 的 `rrulestr/rruleset`，只用于
独立计算期望序列；本库不是它的移植，也不依赖 Python 运行。规则中的日期
`UNTIL=YYYY-MM-DD` 在交给 dateutil 时转换为紧凑日期；查询窗口使用 `inc=True`。
不把另一软件的输出当作完整规范证明，关键错误另有小型可读回归断言。

| 能力 | python-dateutil | MoonRecur 0.2.1 |
| --- | --- | --- |
| 时间粒度 | 日期时间，含更丰富频率/选择器 | 纯日期，四种频率 |
| RRULE 集合 | rrule/rruleset，完整功能更多 | 有界窗口、显式结果上限 |
| 时区、小时、序数星期、BYSETPOS | 有相应支持 | 不支持，不纳入对照 |
| 运行环境 | Python | MoonBit 的 WasmGC/Wasm/JS/native |
| 错误接口 | Python 异常 | Diagnostic 稳定错误码；CLI 状态码 2 |

稀疏工作量用例从 2000-01-01 起，跨度 366000 天，INTERVAL=10000，limit=100，
无例外日期；37 个候选全部输出。这里只证明减少了候选访问，**没有跨语言计时，
不声称比 dateutil 快，也不把访问量比值当作实际运行速度比值**。

本地使用 moon 0.1.20260904 / moonc v0.10.12 工具链完成三种便携目标的
检查、构建、测试、对照和 CLI 验收；native 本地只做检查，实际执行由 Ubuntu CI
验证。CI 会记录实际工具链并保存每目标的 JSON 对照报告。
