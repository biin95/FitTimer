import '../models/exercise_info.dart';

class ExerciseCatalog {
  ExerciseCatalog._();

  static const List<String> categories = [
    '热身',
    '胸部',
    '背部',
    '腿部',
    '肩部',
    '手臂',
    '核心',
    '有氧',
  ];

  static final List<ExerciseInfo> _all = [
    // ═══════════════════════════════════════════════════════════════════
    // 热身
    // ═══════════════════════════════════════════════════════════════════
    const ExerciseInfo(
      id: 'world_greatest_stretch',
      name: '世界最伟大拉伸',
      category: '热身',
      targetMuscles: ['全身', '髋关节', '胸椎'],
      description: '世界最伟大拉伸是一个全身性动态热身动作，结合了弓步、转体和拉伸，能有效激活全身肌群。',
      steps: [
        '站立位，右脚向前迈一大步成弓步',
        '左手撑地，右手向上打开转体',
        '保持2-3秒，感受胸椎旋转',
        '回到站立位，换另一侧重复',
      ],
      tips: [
        '弓步时膝盖不超过脚尖',
        '转体时眼睛跟随手指方向',
        '动作缓慢控制，不要弹振',
        '每侧做3-5次',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/world_greatest_stretch.gif',
    ),
    const ExerciseInfo(
      id: 'dynamic_chest_stretch',
      name: '动态胸部拉伸',
      category: '热身',
      targetMuscles: ['胸大肌', '三角肌前束'],
      description: '动态胸部拉伸能有效打开胸腔，激活胸部和肩部前侧肌群，适合训练前热身。',
      steps: [
        '双脚与肩同宽站立',
        '双臂向两侧打开，掌心向前',
        '感受胸部拉伸感，保持1-2秒',
        '回到起始位置，重复动作',
      ],
      tips: [
        '保持核心收紧，不要塌腰',
        '拉伸幅度逐渐增大',
        '呼吸配合：打开时吸气，收回时呼气',
        '做10-15次',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/dynamic_chest_stretch.gif',
    ),
    const ExerciseInfo(
      id: 'kneeling_lat_stretch',
      name: '跪姿背阔肌拉伸',
      category: '热身',
      targetMuscles: ['背阔肌', '胸椎', '肩部'],
      description: '跪姿背阔肌拉伸能有效放松背部肌群，增加肩关节活动度，适合上肢训练前热身。',
      steps: [
        '四点跪姿，双手前伸',
        '臀部向后坐，手臂尽量前伸',
        '感受背部拉伸感，保持15-20秒',
        '缓慢回到起始位置',
      ],
      tips: [
        '保持呼吸均匀，不要憋气',
        '臀部尽量坐向脚跟',
        '可以左右侧偏增加单侧拉伸',
        '做3-5次',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/kneeling_lat_stretch.gif',
    ),
    const ExerciseInfo(
      id: 'hamstring_stretch',
      name: '腿后侧拉伸',
      category: '热身',
      targetMuscles: ['腘绳肌', '腓肠肌'],
      description: '腿后侧拉伸是经典的下肢热身动作，能有效拉伸腘绳肌，预防腿部训练受伤。',
      steps: [
        '坐姿，一条腿伸直，另一条腿弯曲',
        '身体前倾，双手去够伸直腿的脚尖',
        '感受大腿后侧拉伸感，保持15-20秒',
        '换另一侧重复',
      ],
      tips: [
        '保持背部挺直，不要弓背',
        '拉伸感应在大腿后侧，不是膝盖',
        '不要弹振，保持静态拉伸',
        '每侧做2-3次',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/hamstring_stretch.gif',
    ),
    const ExerciseInfo(
      id: 'calf_stretch_wall',
      name: '靠墙小腿拉伸',
      category: '热身',
      targetMuscles: ['腓肠肌', '比目鱼肌'],
      description: '靠墙小腿拉伸能有效放松小腿肌群，增加踝关节活动度，适合跑步和下肢训练前热身。',
      steps: [
        '面对墙壁站立，双手扶墙',
        '一条腿向后迈一大步，脚跟踩地',
        '前腿弯曲，感受后腿小腿拉伸',
        '保持15-20秒，换另一侧',
      ],
      tips: [
        '后腿保持伸直，脚跟不离地',
        '身体重心前移增加拉伸强度',
        '可以微微弯曲后腿拉伸深层肌群',
        '每侧做2-3次',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/calf_stretch_wall.gif',
    ),
    const ExerciseInfo(
      id: 'neck_side_stretch',
      name: '颈部侧弯拉伸',
      category: '热身',
      targetMuscles: ['斜方肌上束', '肩胛提肌'],
      description: '颈部侧弯拉伸能放松颈部和上斜方肌，缓解久坐带来的颈部紧张，适合所有训练前热身。',
      steps: [
        '坐姿或站姿，保持身体正直',
        '右手轻轻将头向右侧拉',
        '感受左侧颈部拉伸感，保持15-20秒',
        '换另一侧重复',
      ],
      tips: [
        '动作轻柔，不要用力过猛',
        '保持肩膀下沉，不要耸肩',
        '可以微微转头增加拉伸角度',
        '每侧做2-3次',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/neck_side_stretch.gif',
    ),
    const ExerciseInfo(
      id: 'overhead_triceps_stretch',
      name: '过头三头肌拉伸',
      category: '热身',
      targetMuscles: ['肱三头肌', '肩部'],
      description: '过头三头肌拉伸能有效放松手臂后侧肌群，增加肩关节活动度，适合上肢训练前热身。',
      steps: [
        '站立或坐姿，右手举过头顶',
        '右手弯曲，手掌触碰背部中间',
        '左手轻轻按压右手肘部',
        '感受右臂后侧拉伸，保持15-20秒',
      ],
      tips: [
        '保持核心收紧，不要塌腰',
        '拉伸感应在手臂后侧，不是肩膀',
        '可以微微侧弯身体增加拉伸',
        '每侧做2-3次',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/overhead_triceps_stretch.gif',
    ),
    const ExerciseInfo(
      id: 'seated_glute_stretch',
      name: '坐姿臀部拉伸',
      category: '热身',
      targetMuscles: ['臀大肌', '梨状肌'],
      description: '坐姿臀部拉伸能有效放松臀部肌群，增加髋关节活动度，适合下肢训练前热身。',
      steps: [
        '坐姿，一条腿弯曲放在另一条腿上',
        '双手抱住弯曲腿的膝盖',
        '轻轻向胸部拉近',
        '感受臀部拉伸感，保持15-20秒',
      ],
      tips: [
        '保持背部挺直',
        '可以微微前倾增加拉伸强度',
        '不要用力过猛，感受轻微拉伸即可',
        '每侧做2-3次',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/seated_glute_stretch.gif',
    ),
    const ExerciseInfo(
      id: 'upper_back_stretch',
      name: '上背部拉伸',
      category: '热身',
      targetMuscles: ['斜方肌中下束', '菱形肌'],
      description: '上背部拉伸能放松上背部肌群，改善圆肩体态，适合所有训练前热身。',
      steps: [
        '坐姿或站姿，双手向前伸直',
        '双手交叉，手掌向前推',
        '弓背向前，感受上背部拉伸',
        '保持15-20秒，缓慢回到起始位置',
      ],
      tips: [
        '保持呼吸均匀，不要憋气',
        '拉伸感应在肩胛骨之间',
        '可以微微低头增加拉伸',
        '做3-5次',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/upper_back_stretch.gif',
    ),
    // ═══════════════════════════════════════════════════════════════════
    // 胸部
    // ═══════════════════════════════════════════════════════════════════
    const ExerciseInfo(
      id: 'bench_press',
      name: '杠铃卧推',
      category: '胸部',
      targetMuscles: ['胸大肌', '三角肌前束', '肱三头肌'],
      description: '杠铃卧推是最经典的上肢力量训练动作，主要锻炼胸大肌，同时带动三角肌前束和肱三头肌。',
      steps: [
        '仰卧在平板凳上，双脚踩实地面',
        '双手握住杠铃，握距略宽于肩',
        '将杠铃从支架上取下，手臂伸直',
        '缓慢下降杠铃至胸部中下沿',
        '发力推起至起始位置',
      ],
      tips: [
        '肩胛骨后缩下沉，挺胸',
        '腰部保持自然弓起，不要过度反弓',
        '杠铃下放时吸气，推起时呼气',
        '手腕保持中立，不要过度后翻',
      ],
      difficulty: 'intermediate',
      imageAssetPath: 'assets/exercises/bench_press.gif',
    ),
    const ExerciseInfo(
      id: 'incline_bench_press',
      name: '上斜卧推',
      category: '胸部',
      targetMuscles: ['胸大肌上部', '三角肌前束', '肱三头肌'],
      description: '上斜卧推针对胸大肌上部进行强化训练，凳面角度通常设置在30-45度。',
      steps: [
        '将平板凳调至30-45度角',
        '仰卧，双脚踩实地面',
        '双手握距略宽于肩，握住杠铃',
        '缓慢下放至上胸部位置',
        '发力推起至手臂伸直',
      ],
      tips: [
        '角度不宜过大，超过45度会更多刺激肩部',
        '下放位置在锁骨下方约两指处',
        '控制速度，不要借力弹胸',
      ],
      difficulty: 'intermediate',
      imageAssetPath: 'assets/exercises/incline_bench_press.gif',
    ),
    const ExerciseInfo(
      id: 'dumbbell_fly',
      name: '哑铃飞鸟',
      category: '胸部',
      targetMuscles: ['胸大肌', '三角肌前束'],
      description: '哑铃飞鸟是一个优秀的胸部拉伸和塑形动作，能充分拉伸胸大肌纤维。',
      steps: [
        '仰卧在平板凳上，双手各持一只哑铃',
        '双臂微弯，向两侧打开至与肩平齐',
        '感受胸部拉伸后，夹胸将哑铃合拢',
        '在顶部稍作挤压，然后缓慢下放',
      ],
      tips: [
        '全程保持手肘微弯，避免肩关节受伤',
        '不要将哑铃下放过深，与肩平齐即可',
        '想象"抱大树"的动作轨迹',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/dumbbell_fly.gif',
    ),
    const ExerciseInfo(
      id: 'cable_crossover',
      name: '龙门架夹胸',
      category: '胸部',
      targetMuscles: ['胸大肌中缝', '三角肌前束'],
      description: '龙门架夹胸是针对胸肌中缝的孤立训练，通过交叉拉动实现胸部收缩。',
      steps: [
        '将龙门架滑轮调至高位',
        '双手各握住一侧手柄，向前迈一步',
        '身体微微前倾，手臂微弯',
        '双手向身前下方夹拢，直至双手交叉',
        '缓慢回放到起始位置',
      ],
      tips: [
        '保持手肘角度固定不变',
        '在底部充分挤压胸肌',
        '控制回放速度，不要让重量把你拉回去',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/cable_crossover.gif',
    ),
    const ExerciseInfo(
      id: 'push_up',
      name: '俯卧撑',
      category: '胸部',
      targetMuscles: ['胸大肌', '三角肌前束', '肱三头肌', '核心'],
      description: '俯卧撑是最经典的自重上肢训练动作，随时随地可以进行，适合所有训练水平。',
      steps: [
        '双手撑地，间距略宽于肩',
        '身体从头到脚成一条直线',
        '屈肘下降至胸部接近地面',
        '发力推起至手臂伸直',
      ],
      tips: [
        '全程保持核心收紧，不要塌腰或翘臀',
        '手肘不要过度外展，与身体约45度角',
        '如果标准俯卧撑困难，可以跪姿开始',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/push_up.gif',
    ),

    // ═══════════════════════════════════════════════════════════════════
    // 背部
    // ═══════════════════════════════════════════════════════════════════
    const ExerciseInfo(
      id: 'pull_up',
      name: '引体向上',
      category: '背部',
      targetMuscles: ['背阔肌', '肱二头肌', '菱形肌'],
      description: '引体向上是背部训练的王牌动作，主要锻炼背阔肌的宽度，是衡量上肢力量的重要指标。',
      steps: [
        '双手正握单杠，握距略宽于肩',
        '身体悬垂，核心收紧',
        '背部发力，将身体拉起至下巴过杠',
        '缓慢下放至手臂完全伸直',
      ],
      tips: [
        '避免借力摆动身体',
        '想象用肘部去触碰口袋',
        '拉不起来可以先用弹力带辅助',
      ],
      difficulty: 'advanced',
      imageAssetPath: 'assets/exercises/pull_up.gif',
    ),
    const ExerciseInfo(
      id: 'barbell_row',
      name: '杠铃划船',
      category: '背部',
      targetMuscles: ['背阔肌', '菱形肌', '竖脊肌', '肱二头肌'],
      description: '杠铃划船是增加背部厚度的核心训练动作，对整体背部发展至关重要。',
      steps: [
        '双脚与肩同宽站立，屈髋前倾约45度',
        '双手正握杠铃，握距与肩同宽',
        '收紧核心，背部挺直',
        '将杠铃拉向下腹部',
        '顶峰挤压背部后缓慢下放',
      ],
      tips: [
        '保持背部挺直，不要弓背',
        '拉起时感受肩胛骨的收缩',
        '不要用身体晃动来借力',
      ],
      difficulty: 'intermediate',
      imageAssetPath: 'assets/exercises/barbell_row.gif',
    ),
    const ExerciseInfo(
      id: 'lat_pulldown',
      name: '高位下拉',
      category: '背部',
      targetMuscles: ['背阔肌', '大圆肌', '肱二头肌'],
      description: '高位下拉是引体向上的替代动作，适合力量不足完成引体的训练者，能有效锻炼背阔肌。',
      steps: [
        '坐在器械上，大腿固定在垫子下',
        '双手宽握横杆，握距宽于肩',
        '挺胸，将横杆拉至锁骨位置',
        '顶峰挤压背部，缓慢回放',
      ],
      tips: [
        '身体可以微微后倾，但不要过度后仰',
        '想象用肘部向下拉，而不是用手',
        '回放时充分伸展背阔肌',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/lat_pulldown.gif',
    ),
    const ExerciseInfo(
      id: 'seated_row',
      name: '坐姿划船',
      category: '背部',
      targetMuscles: ['背阔肌中部', '菱形肌', '斜方肌中下部'],
      description: '坐姿划船是增加背部厚度的经典器械动作，能很好地刺激背部中线区域。',
      steps: [
        '坐在器械上，双脚踩实踏板',
        '双手握住手柄，挺胸收腹',
        '将手柄拉向下腹部，肩胛骨后缩',
        '顶峰挤压后缓慢回放',
      ],
      tips: [
        '保持挺胸，不要弓背前倾',
        '拉的时候肩胛骨先动，手臂后动',
        '回放时不要完全放松，保持背部张力',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/seated_row.gif',
    ),
    const ExerciseInfo(
      id: 'straight_arm_pulldown',
      name: '直臂下压',
      category: '背部',
      targetMuscles: ['背阔肌', '大圆肌'],
      description: '直臂下压是背阔肌的孤立训练动作，能有效增强背阔肌的收缩感受。',
      steps: [
        '站在龙门架前，双手握住绳索或横杆',
        '手臂伸直，身体微微前倾',
        '保持手臂角度不变，将绳索下压至大腿前',
        '缓慢回放至起始位置',
      ],
      tips: [
        '全程手臂保持微弯，不要完全锁死',
        '专注于背阔肌的收缩感',
        '使用较轻的重量，感受肌肉发力',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/straight_arm_pulldown.gif',
    ),

    // ═══════════════════════════════════════════════════════════════════
    // 腿部
    // ═══════════════════════════════════════════════════════════════════
    const ExerciseInfo(
      id: 'squat',
      name: '杠铃深蹲',
      category: '腿部',
      targetMuscles: ['股四头肌', '臀大肌', '腘绳肌', '核心'],
      description: '杠铃深蹲是"动作之王"，是发展下肢力量和肌肉量最有效的复合动作。',
      steps: [
        '将杠铃放在斜方肌上方（高杠位）或肩胛骨上方（低杠位）',
        '双脚与肩同宽或略宽，脚尖微微外展',
        '屈髋屈膝下蹲，保持背部挺直',
        '蹲至大腿与地面平行或更低',
        '发力站起至起始位置',
      ],
      tips: [
        '膝盖方向与脚尖方向一致',
        '不要让膝盖内扣',
        '下蹲时臀部向后坐，重心在脚掌中后部',
        '全程保持核心收紧',
      ],
      difficulty: 'intermediate',
      imageAssetPath: 'assets/exercises/squat.gif',
    ),
    const ExerciseInfo(
      id: 'deadlift',
      name: '传统硬拉',
      category: '腿部',
      targetMuscles: ['腘绳肌', '臀大肌', '竖脊肌', '斜方肌'],
      description: '硬拉是全身性复合动作，主要锻炼身体后链肌群，对整体力量发展极为重要。',
      steps: [
        '双脚与肩同宽站立，杠铃在脚掌中间',
        '屈髋屈膝，双手正握杠铃',
        '收紧核心，背部挺直',
        '双脚蹬地，将杠铃沿身体拉起',
        '站直后锁定髋部和膝盖',
      ],
      tips: [
        '杠铃全程贴近身体',
        '不要弓背，保持脊柱中立',
        '用臀部和腿发力，不要用腰拉',
        '下放时先屈髋再屈膝',
      ],
      difficulty: 'advanced',
      imageAssetPath: 'assets/exercises/deadlift.gif',
    ),
    const ExerciseInfo(
      id: 'leg_press',
      name: '腿举',
      category: '腿部',
      targetMuscles: ['股四头肌', '臀大肌'],
      description: '腿举是深蹲的安全替代动作，能在较大负重下训练腿部，对腰部压力较小。',
      steps: [
        '坐在腿举器械上，背部紧靠靠垫',
        '双脚踩在踏板上，与肩同宽',
        '松开安全锁',
        '缓慢屈膝下放至大腿靠近胸部',
        '发力推起至膝盖微弯',
      ],
      tips: [
        '下放时不要让臀部离开靠垫',
        '膝盖不要内扣',
        '不要完全锁死膝关节',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/leg_press.gif',
    ),
    const ExerciseInfo(
      id: 'lunge',
      name: '弓步蹲',
      category: '腿部',
      targetMuscles: ['股四头肌', '臀大肌', '腘绳肌'],
      description: '弓步蹲是优秀的单腿训练动作，能改善左右腿力量不平衡，同时锻炼平衡能力。',
      steps: [
        '双脚并拢站立',
        '一脚向前迈一大步',
        '双腿屈膝下蹲，后膝接近地面',
        '前脚发力蹬回起始位置',
      ],
      tips: [
        '前脚膝盖不要超过脚尖太多',
        '保持躯干直立，不要前倾',
        '步幅越大越练臀，步幅越小越练腿',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/lunge.gif',
    ),
    const ExerciseInfo(
      id: 'leg_curl',
      name: '腿弯举',
      category: '腿部',
      targetMuscles: ['腘绳肌', '腓肠肌'],
      description: '腿弯举是腘绳肌的孤立训练动作，分为俯卧式和坐姿式两种。',
      steps: [
        '俯卧在器械上，脚踝固定在垫子下',
        '双手握住把手',
        '屈膝将脚跟向臀部方向勾起',
        '顶峰挤压后缓慢下放',
      ],
      tips: [
        '臀部不要抬起离开垫子',
        '下放时不要完全放到底，保持张力',
        '控制速度，不要靠惯性甩',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/leg_curl.gif',
    ),
    const ExerciseInfo(
      id: 'leg_extension',
      name: '腿屈伸',
      category: '腿部',
      targetMuscles: ['股四头肌'],
      description: '腿屈伸是股四头肌的孤立训练动作，适合在复合动作后进行补充训练。',
      steps: [
        '坐在器械上，背部紧靠靠垫',
        '小腿前侧贴在垫子下',
        '发力伸直膝关节',
        '顶峰挤压股四头肌后缓慢下放',
      ],
      tips: [
        '不要用惯性甩起重量',
        '在顶部停留1-2秒效果更好',
        '下放时不要完全放到底',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/leg_extension.gif',
    ),
    const ExerciseInfo(
      id: 'calf_raise',
      name: '坐姿提踵',
      category: '腿部',
      targetMuscles: ['腓肠肌', '比目鱼肌'],
      description: '坐姿提踵是小腿训练的基础动作，通过器械负重有效增强小腿肌肉力量和围度。',
      steps: [
        '坐在提踵器械上，前脚掌踩在踏板上',
        '膝盖顶住上方垫子',
        '发力踮起脚尖至最高点',
        '顶峰挤压后缓慢下放至最低',
      ],
      tips: [
        '在最低点充分拉伸小腿',
        '在最高点停留挤压1-2秒',
        '可以调整脚尖方向内外侧重不同区域',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/calf_raise.gif',
    ),

    // ═══════════════════════════════════════════════════════════════════
    // 肩部
    // ═══════════════════════════════════════════════════════════════════
    const ExerciseInfo(
      id: 'overhead_press',
      name: '杠铃推举',
      category: '肩部',
      targetMuscles: ['三角肌前束', '三角肌中束', '肱三头肌'],
      description: '杠铃推举是肩部力量训练的核心动作，也是衡量上肢推力的重要指标。',
      steps: [
        '双脚与肩同宽站立',
        '双手握住杠铃，握距略宽于肩，杠铃置于锁骨前方',
        '收紧核心，发力将杠铃推过头顶',
        '手臂伸直后锁定，杠铃在头部正上方',
        '缓慢下放至起始位置',
      ],
      tips: [
        '推举时头部微微后仰让路',
        '全程收紧核心，不要过度反弓腰部',
        '杠铃轨迹应该是垂直向上',
      ],
      difficulty: 'intermediate',
      imageAssetPath: 'assets/exercises/overhead_press.gif',
    ),
    const ExerciseInfo(
      id: 'lateral_raise',
      name: '哑铃侧平举',
      category: '肩部',
      targetMuscles: ['三角肌中束'],
      description: '侧平举是塑造肩部宽度的关键动作，专门针对三角肌中束进行孤立训练。',
      steps: [
        '双脚与肩同宽站立，双手各持一只哑铃',
        '手臂微弯，放在身体两侧',
        '保持手肘角度不变，向两侧举起哑铃',
        '举至与肩平齐后缓慢下放',
      ],
      tips: [
        '小拇指微微上翻，有助于更好刺激中束',
        '不要耸肩，保持肩胛骨下沉',
        '使用较轻的重量，避免借力',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/lateral_raise.gif',
    ),
    const ExerciseInfo(
      id: 'front_raise',
      name: '绳索前平举',
      category: '肩部',
      targetMuscles: ['三角肌前束'],
      description: '绳索前平举是针对三角肌前束的孤立训练动作，绳索能提供持续的张力，比哑铃更稳定。',
      steps: [
        '站在龙门架侧面，单手握住绳索手柄',
        '手臂伸直放在身体前方',
        '发力将绳索举至与肩平齐',
        '缓慢下放至起始位置',
      ],
      tips: [
        '不要借助身体晃动来借力',
        '举至眼睛高度即可，不要过高',
        '控制下放速度，感受持续张力',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/front_raise.gif',
    ),
    const ExerciseInfo(
      id: 'face_pull',
      name: '龙门架绳索面拉',
      category: '肩部',
      targetMuscles: ['三角肌后束', '菱形肌', '斜方肌中下部'],
      description: '龙门架绳索面拉是改善圆肩和强化肩后束的经典器械动作，通过绳索提供持续张力，是肩部健康训练的必备动作。',
      steps: [
        '将龙门架滑轮调至与面部同高的位置',
        '双手握住绳索两端，后退一步站立',
        '大臂与地面平行，将绳索拉向面部两侧',
        '双手分开至耳朵两侧，肩胛骨后缩',
        '缓慢回放至起始位置',
      ],
      tips: [
        '拉的时候大臂保持与地面平行',
        '在末端充分外旋肩关节，感受后束收缩',
        '保持挺胸，不要后仰借力',
        '使用较轻的重量，专注于肌肉感受',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/face_pull.gif',
    ),
    const ExerciseInfo(
      id: 'reverse_fly',
      name: '反向飞鸟',
      category: '肩部',
      targetMuscles: ['三角肌后束', '菱形肌'],
      description: '反向飞鸟主要锻炼三角肌后束和上背部，有助于改善体态和肩部平衡发展。',
      steps: [
        '俯身或坐在器械上，双手各持哑铃或握住手柄',
        '手臂微弯，向两侧打开',
        '感受肩后束和肩胛骨的收缩',
        '缓慢回放至起始位置',
      ],
      tips: [
        '保持手肘微弯，不要锁死',
        '想象用肩胛骨去夹一支笔',
        '使用较轻的重量，专注于感受',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/reverse_fly.gif',
    ),
    const ExerciseInfo(
      id: 'shrug',
      name: '杠铃耸肩',
      category: '肩部',
      targetMuscles: ['斜方肌上部'],
      description: '耸肩是斜方肌上部的针对性训练动作，能增强颈部周围的肌肉力量。',
      steps: [
        '双脚与肩同宽站立，双手握住杠铃',
        '手臂伸直，杠铃自然下垂',
        '肩膀向上耸起至最高点',
        '顶峰挤压后缓慢下放',
      ],
      tips: [
        '不要转动肩膀，直接向上耸',
        '想象用肩膀去碰耳朵',
        '可以使用助力带握住更重的重量',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/shrug.gif',
    ),

    // ═══════════════════════════════════════════════════════════════════
    // 手臂
    // ═══════════════════════════════════════════════════════════════════
    const ExerciseInfo(
      id: 'barbell_curl',
      name: '杠铃弯举',
      category: '手臂',
      targetMuscles: ['肱二头肌', '肱肌'],
      description: '杠铃弯举是二头肌训练的基础动作，能使用较大重量进行训练。',
      steps: [
        '双脚与肩同宽站立，双手反握杠铃',
        '上臂夹紧身体两侧',
        '弯举杠铃至肩部位置',
        '顶峰挤压后缓慢下放',
      ],
      tips: [
        '上臂保持不动，只有前臂移动',
        '不要用身体晃动来借力',
        '下放时控制速度，不要自由落体',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/barbell_curl.gif',
    ),
    const ExerciseInfo(
      id: 'dumbbell_curl',
      name: '哑铃弯举',
      category: '手臂',
      targetMuscles: ['肱二头肌', '肱肌', '肱桡肌'],
      description: '哑铃弯举能进行单侧训练，有助于纠正左右臂力量不平衡。',
      steps: [
        '站立或坐在凳上，双手各持一只哑铃',
        '上臂夹紧身体',
        '交替或同时弯举哑铃',
        '顶峰挤压后缓慢下放',
      ],
      tips: [
        '可以在弯举过程中外旋手腕，增加收缩感',
        '不要甩哑铃，控制节奏',
        '可以靠墙练习防止借力',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/dumbbell_curl.gif',
    ),
    const ExerciseInfo(
      id: 'hammer_curl',
      name: '锤式弯举',
      category: '手臂',
      targetMuscles: ['肱肌', '肱桡肌', '肱二头肌'],
      description: '锤式弯举采用对握方式，能更好地刺激肱肌和肱桡肌，增加手臂整体围度。',
      steps: [
        '站立，双手各持一只哑铃，掌心相对',
        '上臂夹紧身体',
        '保持对握姿势弯举哑铃',
        '顶峰挤压后缓慢下放',
      ],
      tips: [
        '全程保持掌心相对',
        '不要晃动身体',
        '这个动作也对前臂有很好的训练效果',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/hammer_curl.gif',
    ),
    const ExerciseInfo(
      id: 'tricep_pushdown',
      name: '三头下压',
      category: '手臂',
      targetMuscles: ['肱三头肌'],
      description: '三头下压是肱三头肌最常见的孤立训练动作，适合所有训练水平。',
      steps: [
        '面对龙门架站立，双手握住绳索或横杆',
        '上臂夹紧身体两侧',
        '保持上臂不动，将手柄下压至手臂伸直',
        '缓慢回放至起始位置',
      ],
      tips: [
        '上臂始终贴紧身体',
        '在底部充分收缩三头肌',
        '不要让重量把你拉得身体前倾',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/tricep_pushdown.gif',
    ),
    const ExerciseInfo(
      id: 'tricep_dip',
      name: '臂屈伸',
      category: '手臂',
      targetMuscles: ['肱三头肌', '胸大肌下部', '三角肌前束'],
      description: '臂屈伸是上肢推力的经典自重动作，对三头肌和下胸有很好的刺激效果。',
      steps: [
        '双手撑在双杠上，手臂伸直',
        '身体前倾约30度',
        '屈肘下降至大臂与地面平行',
        '发力推起至手臂伸直',
      ],
      tips: [
        '身体越前倾越练胸，越直立越练三头',
        '不要耸肩，保持肩膀下沉',
        '如果体重太大，可以用弹力带辅助',
      ],
      difficulty: 'intermediate',
      imageAssetPath: 'assets/exercises/tricep_dip.gif',
    ),
    const ExerciseInfo(
      id: 'concentration_curl',
      name: '集中弯举',
      category: '手臂',
      targetMuscles: ['肱二头肌'],
      description: '集中弯举是二头肌的孤立训练动作，通过固定上臂来最大限度地刺激二头肌。',
      steps: [
        '坐在凳上，双脚分开',
        '一手持哑铃，肘部顶在大腿内侧',
        '弯举哑铃至肩部',
        '顶峰挤压后缓慢下放',
      ],
      tips: [
        '肘部紧贴大腿，不要移动',
        '在顶部充分挤压二头肌',
        '下放时手臂完全伸直',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/concentration_curl.gif',
    ),

    // ═══════════════════════════════════════════════════════════════════
    // 核心
    // ═══════════════════════════════════════════════════════════════════
    const ExerciseInfo(
      id: 'plank',
      name: '平板支撑',
      category: '核心',
      targetMuscles: ['腹直肌', '腹横肌', '竖脊肌'],
      description: '平板支撑是最基础的核心稳定性训练动作，能有效增强核心肌群的等长收缩能力。',
      steps: [
        '俯卧，双肘撑地，与肩同宽',
        '双脚踩地，身体从头到脚成一条直线',
        '收紧腹部，保持这个姿势',
        '坚持目标时间',
      ],
      tips: [
        '不要塌腰或翘臀',
        '保持正常呼吸，不要憋气',
        '如果腰部酸痛说明姿势不对',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/plank.gif',
    ),
    const ExerciseInfo(
      id: 'crunch',
      name: '卷腹',
      category: '核心',
      targetMuscles: ['腹直肌上部'],
      description: '卷腹是最经典的腹部训练动作，针对腹直肌上部进行有效刺激。',
      steps: [
        '仰卧，双膝弯曲，双脚踩地',
        '双手放在耳侧或胸前',
        '收紧腹部，将肩胛骨抬离地面',
        '在顶部挤压腹部后缓慢下放',
      ],
      tips: [
        '不要用手拉头部',
        '下背部始终贴紧地面',
        '动作幅度不用太大，感受腹肌收缩即可',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/crunch.gif',
    ),
    const ExerciseInfo(
      id: 'russian_twist',
      name: '俄罗斯转体',
      category: '核心',
      targetMuscles: ['腹内外斜肌', '腹直肌'],
      description: '俄罗斯转体是锻炼腹斜肌的经典动作，能增强躯干的旋转力量。',
      steps: [
        '坐在地上，双膝弯曲',
        '双脚微微离地，身体后倾约45度',
        '双手合十或持重物',
        '转动躯干，双手交替触碰左右两侧地面',
      ],
      tips: [
        '转动时跟随双手转动视线',
        '保持核心收紧，不要弓背',
        '可以抬脚增加难度',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/russian_twist.gif',
    ),
    const ExerciseInfo(
      id: 'hanging_leg_raise',
      name: '悬垂举腿',
      category: '核心',
      targetMuscles: ['腹直肌下部', '髂腰肌'],
      description: '悬垂举腿是高级核心训练动作，对腹肌下部和髋屈肌有极强的刺激效果。',
      steps: [
        '双手握住单杠，身体悬垂',
        '保持腿部伸直或微弯',
        '发力将双腿举至与地面平行',
        '缓慢下放至起始位置',
      ],
      tips: [
        '不要用惯性甩腿',
        '下放时控制速度，不要自由落体',
        '如果举直腿困难，可以屈膝开始',
      ],
      difficulty: 'advanced',
      imageAssetPath: 'assets/exercises/hanging_leg_raise.gif',
    ),
    const ExerciseInfo(
      id: 'dead_bug',
      name: '鸟狗式',
      category: '核心',
      targetMuscles: ['腹横肌', '竖脊肌', '臀大肌'],
      description: '鸟狗式是安全的核心稳定性训练动作，能同时强化核心和臀部，改善身体平衡能力。',
      steps: [
        '四点跪撑，双手在肩正下方，膝盖在髋正下方',
        '收紧核心，保持背部平直',
        '同时伸出对侧手和脚（左手右脚）',
        '保持2-3秒后收回，换另一侧重复',
      ],
      tips: [
        '全程保持背部平直，不要塌腰或弓背',
        '动作要慢，不要急',
        '伸出时想象头顶和脚跟向两端拉长',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/dead_bug.gif',
    ),

    // ═══════════════════════════════════════════════════════════════════
    // 有氧
    // ═══════════════════════════════════════════════════════════════════
    const ExerciseInfo(
      id: 'treadmill',
      name: '跑步机跑步',
      category: '有氧',
      targetMuscles: ['股四头肌', '腘绳肌', '腓肠肌', '心肺'],
      description: '跑步机是最常见的有氧训练设备，适合各种训练水平，可自由调节速度和坡度。',
      steps: [
        '站在跑步机两侧踏板上，启动机器',
        '从慢走开始热身2-3分钟',
        '逐渐加速至目标配速',
        '保持稳定节奏跑步',
        '结束前逐渐减速冷却',
      ],
      tips: [
        '保持正确跑姿，身体微微前倾',
        '不要抓扶手跑步',
        '跑步时脚掌着地方式要自然',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/treadmill.gif',
    ),
    const ExerciseInfo(
      id: 'rowing_machine',
      name: '坐姿划船',
      category: '有氧',
      targetMuscles: ['背阔肌', '菱形肌', '肱二头肌', '心肺'],
      description: '坐姿划船是健身房常见的背部训练器械，能有效锻炼背部肌群，同时提升心肺耐力。',
      steps: [
        '坐在器械上，双脚踩实踏板',
        '双手握住手柄，挺胸收腹',
        '将手柄拉向下腹部，肩胛骨后缩',
        '顶峰挤压后缓慢回放',
      ],
      tips: [
        '保持挺胸，不要弓背前倾',
        '拉的时候肩胛骨先动，手臂后动',
        '回放时不要完全放松，保持背部张力',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/rowing_machine.gif',
    ),
    const ExerciseInfo(
      id: 'jump_rope',
      name: '高抬腿跳',
      category: '有氧',
      targetMuscles: ['股四头肌', '髂腰肌', '心肺'],
      description: '高抬腿跳是高效的有氧热身动作，能快速提升心率，同时锻炼腿部和核心。',
      steps: [
        '双脚与肩同宽站立',
        '交替抬起膝盖至腰部高度',
        '配合手臂自然摆动',
        '保持节奏连续进行',
      ],
      tips: [
        '前脚掌着地，膝盖微弯',
        '保持上身挺直，不要前倾',
        '可以加快速度提高心率',
        '初学者可以扶墙保持平衡',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/jump_rope.gif',
    ),
    const ExerciseInfo(
      id: 'jumping_jack',
      name: '开合跳',
      category: '有氧',
      targetMuscles: ['全身肌群', '心肺'],
      description: '开合跳是最简单的全身有氧动作，不需要任何器械，适合热身和间歇训练。',
      steps: [
        '双脚并拢站立，双手放在身体两侧',
        '跳起的同时双脚分开，双手举过头顶',
        '再次跳起回到起始位置',
        '重复进行',
      ],
      tips: [
        '保持节奏稳定',
        '前脚掌着地，膝盖微弯',
        '可以加快速度提高心率',
      ],
      difficulty: 'beginner',
      imageAssetPath: 'assets/exercises/jumping_jack.gif',
    ),
  ];

  /// 获取全部动作。
  static List<ExerciseInfo> getAll() => _all;

  /// 按分类获取动作。
  static List<ExerciseInfo> getByCategory(String category) {
    return _all.where((e) => e.category == category).toList();
  }

  /// 按 ID 查找动作。
  static ExerciseInfo? getById(String id) {
    try {
      return _all.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 按名称模糊搜索。
  static List<ExerciseInfo> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all
        .where((e) =>
            e.name.toLowerCase().contains(q) ||
            e.category.toLowerCase().contains(q) ||
            e.targetMuscles.any((m) => m.toLowerCase().contains(q)))
        .toList();
  }

  /// 通过动作名模糊匹配（用于关联用户输入的动作名）。
  static ExerciseInfo? matchByName(String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return null;
    // 精确匹配
    for (final e in _all) {
      if (e.name.toLowerCase() == n) return e;
    }
    // 包含匹配
    for (final e in _all) {
      if (e.name.toLowerCase().contains(n) || n.contains(e.name.toLowerCase())) {
        return e;
      }
    }
    return null;
  }
}
