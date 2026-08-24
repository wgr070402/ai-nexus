import 'package:flutter/material.dart';

/// 生成结果的输出类型，决定结果区的操作按钮（保存文件名/是否代码）。
enum GenOutputType {
  /// 普通文本 / Markdown。
  text('text'),

  /// 源代码（可保存到工作区、在终端运行）。
  code('code'),

  /// 表格 / CSV 数据。
  table('table'),

  /// Mermaid 流程图 / 架构图。
  mermaid('mermaid');

  const GenOutputType(this.ext);
  final String ext;
}

/// 一个内置生成器模板（AI 生成器中心）。
class GeneratorTemplate {
  const GeneratorTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.systemPrompt,
    required this.outputType,
    required this.defaultFileName,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final String systemPrompt;
  final GenOutputType outputType;

  /// 保存到工作区时的默认文件名。
  final String defaultFileName;
}

/// 内置生成器模板库，覆盖 P1/P2 大部分「生成类」需求。
class GeneratorTemplateRegistry {
  GeneratorTemplateRegistry._();

  static const List<GeneratorTemplate> templates = <GeneratorTemplate>[
    GeneratorTemplate(
      id: 'demo',
      name: 'Demo 原型',
      description: '输入需求，产出可运行的 Python 工具 / 网页 Demo / 命令行小游戏',
      icon: Icons.rocket_launch_outlined,
      outputType: GenOutputType.code,
      defaultFileName: 'demo.py',
      systemPrompt: '你是一名快速原型开发者。根据用户需求，产出【完整、可直接运行】的'
          '最小 Demo：Python 小工具、网页 Demo 或命令行小游戏。只输出代码，'
          '代码带必要注释，不要额外解释。',
    ),
    GeneratorTemplate(
      id: 'scaffold',
      name: '项目脚手架',
      description: '生成网页前端 / 后端接口 / Python 工具的项目骨架与目录结构',
      icon: Icons.dashboard_customize_outlined,
      outputType: GenOutputType.code,
      defaultFileName: 'scaffold.md',
      systemPrompt: '你是一名架构师。根据用户需求生成项目脚手架方案，'
          '用 Markdown 输出：目录结构（代码块）、每个核心文件的用途说明、'
          '以及关键的基础配置文件内容（package.json / requirements.txt 等）。',
    ),
    GeneratorTemplate(
      id: 'comments',
      name: '注释 / 翻译',
      description: '给整套代码批量写注释、中英文互转、生成接口文档',
      icon: Icons.translate_outlined,
      outputType: GenOutputType.code,
      defaultFileName: 'commented.md',
      systemPrompt: '你是一名代码文档专家。对用户提供的代码：批量生成清晰注释、'
          '进行中英文互译、或生成接口 Markdown 文档。保留原代码结构，'
          '只做注释/翻译/文档增强。',
    ),
    GeneratorTemplate(
      id: 'unittest',
      name: '单元测试',
      description: '针对给定代码自动生成测试用例',
      icon: Icons.fact_check_outlined,
      outputType: GenOutputType.code,
      defaultFileName: 'test.py',
      systemPrompt: '你是一名测试工程师。针对用户提供的代码，生成覆盖主要分支的单元测试，'
          '使用对应语言的主流测试框架（Python 用 unittest/pytest）。只输出可运行测试代码。',
    ),
    GeneratorTemplate(
      id: 'textgame',
      name: '文字游戏',
      description: '文字冒险 / 回合对战 / 解谜小游戏（Python，可在终端试玩）',
      icon: Icons.keyboard_outlined,
      outputType: GenOutputType.code,
      defaultFileName: 'game.py',
      systemPrompt: '你是一名文字游戏开发者。生成一个完整的 Python 控制台文字游戏'
          '（文字冒险 / 回合对战 / 解谜均可），可直接在终端运行试玩。'
          '只输出完整可运行的 Python 代码。',
    ),
    GeneratorTemplate(
      id: 'webgame',
      name: '网页小游戏',
      description: '生成 HTML+JS 小游戏（贪吃蛇 / 打砖块 / 简易 RPG）',
      icon: Icons.sports_esports_outlined,
      outputType: GenOutputType.code,
      defaultFileName: 'game.html',
      systemPrompt: '你是一名前端游戏开发者。生成一个完整的 HTML+JS 网页小游戏'
          '（贪吃蛇 / 打砖块 / 简易 RPG 等），单文件、无需外部依赖，'
          '可在浏览器直接打开试玩。只输出完整 HTML 代码。',
    ),
    GeneratorTemplate(
      id: 'gamedesign',
      name: '游戏设定',
      description: '世界观、怪物属性、技能、装备、关卡策划表',
      icon: Icons.table_chart_outlined,
      outputType: GenOutputType.table,
      defaultFileName: 'game_design.md',
      systemPrompt: '你是一名游戏策划。生成游戏设定：世界观、怪物属性表、技能表、'
          '装备表、关卡策划表。使用 Markdown 表格输出，字段清晰、数值合理。',
    ),
    GeneratorTemplate(
      id: 'docproc',
      name: '文档处理',
      description: '解析 txt/markdown，长文总结、改写、生成思维导图大纲',
      icon: Icons.summarize_outlined,
      outputType: GenOutputType.text,
      defaultFileName: 'summary.md',
      systemPrompt: '你是一名文档处理专家。对用户提供的文档：长文总结、改写润色、'
          '或生成思维导图大纲（Markdown 列表层级）。输出为清晰的 Markdown。',
    ),
    GeneratorTemplate(
      id: 'script',
      name: '批量脚本',
      description: '文件重命名、文本批量替换、简单数据处理脚本',
      icon: Icons.terminal_outlined,
      outputType: GenOutputType.code,
      defaultFileName: 'script.py',
      systemPrompt: '你是一名脚本开发者。根据用户需求生成批量处理脚本：文件重命名、'
          '文本批量替换、简单数据处理等。使用 Python，完整可运行，只输出代码。',
    ),
    GeneratorTemplate(
      id: 'mockdata',
      name: '数据模拟',
      description: '生成模拟测试数据、表格数据，可导出 CSV',
      icon: Icons.storage_outlined,
      outputType: GenOutputType.table,
      defaultFileName: 'mock_data.csv',
      systemPrompt: '你是一名数据工程师。根据用户需求生成模拟测试数据，'
          '输出 CSV 格式（含表头）或 Markdown 表格。数据应真实合理、可重复。',
    ),
    GeneratorTemplate(
      id: 'mermaid',
      name: '流程图 / 架构图',
      description: '输出 Mermaid 流程图，展示项目架构、游戏流程逻辑',
      icon: Icons.account_tree_outlined,
      outputType: GenOutputType.mermaid,
      defaultFileName: 'diagram.mmd',
      systemPrompt: '你是一名架构师。根据用户描述，输出 Mermaid 流程图'
          '（flowchart/sequenceDiagram/classDiagram 等），展示项目架构或游戏流程逻辑。'
          '只输出 Mermaid 代码块。',
    ),
  ];
}
