# 角色差异化权限 — 设计文档

**日期**: 2026-07-31  
**状态**: 已确认  
**分支**: feature/eco-system

---

## 背景

当前身份切换功能（学生🧒 / 老师👩‍🏫 / 家长👨‍👩‍👧）的安全机制已完善（AES 加密、锁定、日志），但角色切换只改变显示标签，不改变任何功能行为。需要实现角色差异化功能体验。

## 目标

- **权限控制**: 不同角色对功能有不同的访问权限
- **数据视角**: 老师/家长可通过观察窗查看学生数据
- **UI 统一**: 保持统一视觉风格，仅通过功能入口显隐区分角色

## 权限规则

| 功能 | 学生 | 老师 | 家长 |
|------|:----:|:----:|:----:|
| 哼唱创作（录音+编曲） | ✅ | ✅ | ❌ |
| 编辑作品 | ✅ | ✅ | ❌ |
| 删除作品 | ✅ | ✅ | ❌ |
| 切换身份 | ✅ | ✅ | ✅ |
| 修改身份切换密码 | ❌ | ❌ | ✅ |
| 访问观察窗 | ❌ | ✅ | ✅ |
| 访问隐私设置页 | ✅ | ✅ | ✅ |

## 架构方案：集中式角色门控（方案 A）

### 新增文件

1. **`sing_sprout/lib/shared/services/role_permissions.dart`**
   - `Feature` 枚举：所有可门控的功能
   - `rolePermissions` 常量 Map：`Feature → Set<UserRole>` 权限映射
   - 单一真相源，添加/修改权限只改这一个文件

2. **`sing_sprout/lib/shared/widgets/role_gate.dart`**
   - `RoleGate` widget：接收 `feature` + `role` + `child`，按权限显示/隐藏
   - 可选 `fallback` widget：无权限时显示替代内容
   - 静态方法 `isAllowed(feature, role)` 供代码中判断

### 修改文件

| 文件 | 改动内容 |
|------|----------|
| `profile_page.dart` | 切换身份、隐私与安全菜单项包裹 RoleGate |
| `humming_garden_page.dart` | 创作入口包裹 RoleGate，家长模式显示只读提示 |
| `editor_page.dart` | 编辑/保存按钮包裹 RoleGate |
| `works_page.dart` | 删除按钮包裹 RoleGate |
| `privacy_settings_page.dart` | 修改密码入口仅家长可见（RoleGate） |
| `observation_page.dart` | 入口已在 profile_page，无需额外改动 |

## 非目标（本次不做）

- 多学生档案支持
- 老师布置任务系统
- 不同角色不同 UI 风格
- 声音邮局对外通讯限制
- 田野录音角色限制

## 自审清单

- [x] 无 TBD/TODO
- [x] 权限规则无内部矛盾
- [x] 改动范围可控（新增 2 文件 + 修改 6 文件）
- [x] 权限定义单一文件，无歧义
