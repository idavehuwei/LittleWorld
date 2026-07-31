# 《哼哼的小小世界》简单动物 AI 方案

## 1. 目标

世界生成完成后，在自然地表确定性随机生成猪和鸡各 6–10 只，总计 12–20 只。两种动物都有独立的数量下限，不会因随机分配导致某一种过少。动物平时在地表缓慢游荡并偶尔停下，玩家靠近到 3 米以内时向远离玩家的方向逃跑，持续一段时间后恢复游荡。

## 2. 场景结构

```text
Animals (AnimalSpawner / Node3D)
└── Pig_01 或 Chicken_01 (SimpleAnimal / CharacterBody3D)
    ├── BodyCollision (CollisionShape3D)
    ├── VisualRoot (Node3D)
    │   ├── Body (MeshInstance3D / BoxMesh)
    │   ├── Head (MeshInstance3D / BoxMesh)
    │   ├── Legs... (MeshInstance3D / BoxMesh)
    │   └── Snout 或 Beak... (MeshInstance3D / BoxMesh)
    ├── ObstacleRay (RayCast3D)
    └── GroundAheadRay (RayCast3D)
```

`CharacterBody3D` 提供重力、地面检测、墙体滑动和稳定的动态角色碰撞；`VisualRoot` 与物理主体分离，方便用整体上下浮动和轻微缩放表现脚步，无需骨骼动画。

碰撞层约定：

```text
Layer 1：方块世界
Layer 2：玩家
Layer 4：动物
```

动物的 `collision_mask` 当前只检测世界 Layer 1，因此不会穿过实体方块，也不会因为动物彼此挤压而形成大量物理解算。

## 3. 状态机

```gdscript
enum State {
    IDLE,
    WANDER,
    FLEE,
}
```

### IDLE（空闲）

- 水平速度逐步减为 0。
- 停留约 0.8–2.4 秒。
- 计时结束后进入 `WANDER`。

### WANDER（游荡）

- 随机选择水平移动方向。
- 以约 1.15 米/秒缓慢行走。
- 每次持续约 2.4–5.5 秒。
- 计时结束后大概率进入 `IDLE`，也可能更换方向继续游荡。

### FLEE（逃跑）

当玩家水平距离小于 3 米时：

```gdscript
movement_direction = (
    animal.global_position - player.global_position
)
movement_direction.y = 0.0
movement_direction = movement_direction.normalized()
```

- 以约 3.2 米/秒逃跑。
- 玩家仍在 3 米内时刷新逃跑计时。
- 玩家离开后，逃跑约 2.4 秒再恢复 `WANDER`。

## 4. 重力与防穿墙

每个物理帧执行：

```text
应用重力
→ 更新 AI 状态
→ 检测障碍和悬崖
→ 设置水平速度
→ move_and_slide()
→ 更新整体移动动画
```

动物脚底作为 `CharacterBody3D` 原点，使用 `floor_snap_length` 提高贴地稳定性。落地时清除向下速度，离地时以 18 米/秒²施加重力。实体方块由 GridMap 提供碰撞，`move_and_slide()` 阻止动物穿墙。

## 5. 简单射线导航

本阶段不使用 `NavigationAgent3D`，而采用两条局部射线：

- `ObstacleRay`：从身体前方检测墙体或方块障碍。
- `GroundAheadRay`：从前下方检测下一步是否仍有地面。

命中墙、前方无地面或接近世界边缘时，动物随机向左或向右旋转约 43°–83°，并设置短暂转向冷却，避免连续抖动。

### 与 NavigationAgent3D 的比较

`NavigationAgent3D` 适合静态或低频变化的连续地形，能进行较长距离路径规划；但本项目允许玩家随时破坏和放置方块，静态 NavigationMesh 会迅速失效。对当前 12–20 只、只需局部游荡和逃跑的动物，简单射线具有以下优势：

- 不需要为 250×250 体素世界烘焙导航网格。
- 方块变化后无需重新烘焙。
- 计算量低，行为容易测试。
- 与 GridMap 的实时碰撞结果保持一致。

未来若加入回家、寻找食物、跨区域追踪等长距离目标，可改为“Chunk 层级 A* + 局部射线避障”，而不是每次编辑方块都重建整张 NavigationMesh。

## 6. 随机生成规则

`AnimalSpawner` 使用固定种子 `20260817`：

1. 分别随机确定 6–10 只猪和 6–10 只鸡，总数为 12–20 只。
2. 依次为猪、鸡寻找安全地表点，确保两种动物都达到各自目标数量。
3. 在世界边缘内缩 8 格的范围选择坐标。
3. 通过 `world.get_surface_height(x, z)` 查询地表。
4. 要求脚下为草方块，身体两格空间为空。
5. 避开玩家出生点 14 格范围。
6. 要求四邻地表高差不超过 1，避免生成在尖峰和陡崖上。
7. 动物之间至少间隔 3 米。
8. 每只动物随机分配为猪或鸡。

固定种子使测试和演示结果可复现；若正式游戏需要每个新世界不同，可将种子改为世界存档种子派生值。

## 7. 方块组合模型

猪由身体、头、鼻子、眼睛和四条腿组成；鸡由身体、头、喙、鸡冠、眼睛和双腿组成。全部使用代码创建的 `BoxMesh` 和纯色 `StandardMaterial3D`，无需外部模型文件。

移动时只改变 `VisualRoot`：

- 游荡：轻微上下浮动。
- 逃跑：提高浮动频率和幅度。
- 按浮动相位轻微压缩 Y、拉伸 X/Z，形成低成本的方块风格步态。

## 8. 代码职责

- `scripts/simple_animal.gd`：动物碰撞体、模型、状态机、重力、逃跑和局部避障。
- `scripts/animal_spawner.gd`：动物数量、类型、地表安全点和确定性生成。
- `scripts/main.gd`：在世界和玩家创建完成后装配 `AnimalSpawner`。
- `test/test_animal_ai.gd`：验证生成数量、类型、模型结构、地表位置、重力碰撞、状态切换、逃跑方向、边缘转向和固定种子一致性。
