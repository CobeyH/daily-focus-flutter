import 'package:flutter/material.dart';

class TaskIconChoice {
  final IconData icon;
  final String label;
  final String category;
  final String keywords;

  const TaskIconChoice(this.icon, this.label, this.category, this.keywords);

  bool matches(String query) {
    final words = '$label $category $keywords'.toLowerCase();
    return query
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .every(words.contains);
  }
}

// Keep explicit const IconData references so release builds can tree-shake the
// font. The original ten code points remain supported for saved tasks.
const taskIconChoices = <TaskIconChoice>[
  TaskIconChoice(
      Icons.local_florist, 'Plants', 'Outdoors', 'garden flower water'),
  TaskIconChoice(Icons.fitness_center, 'Strength', 'Movement',
      'gym weights exercise workout'),
  TaskIconChoice(
      Icons.menu_book, 'Reading', 'Learning & work', 'book study literature'),
  TaskIconChoice(Icons.self_improvement, 'Meditation', 'Wellbeing',
      'mindful yoga breathe calm'),
  TaskIconChoice(
      Icons.restaurant, 'Meals', 'Food & drink', 'eat dinner lunch breakfast'),
  TaskIconChoice(Icons.bed, 'Sleep', 'Wellbeing', 'bed rest bedtime nap'),
  TaskIconChoice(
      Icons.directions_run, 'Running', 'Movement', 'jog exercise cardio'),
  TaskIconChoice(
      Icons.edit, 'Writing', 'Creativity', 'journal pen diary notes'),
  TaskIconChoice(
      Icons.check_circle, 'Habit', 'Everyday', 'check task complete routine'),
  TaskIconChoice(
      Icons.water_drop, 'Water', 'Food & drink', 'drink hydration glass'),
  TaskIconChoice(
      Icons.directions_walk, 'Walking', 'Movement', 'steps stroll exercise'),
  TaskIconChoice(Icons.directions_bike, 'Cycling', 'Movement',
      'bike bicycle ride exercise'),
  TaskIconChoice(Icons.pool, 'Swimming', 'Movement', 'water swim exercise'),
  TaskIconChoice(Icons.sports_gymnastics, 'Stretching', 'Movement',
      'flexibility exercise mobility'),
  TaskIconChoice(
      Icons.sports_soccer, 'Football', 'Movement', 'soccer sport ball team'),
  TaskIconChoice(
      Icons.sports_tennis, 'Tennis', 'Movement', 'racket sport pickleball'),
  TaskIconChoice(
      Icons.sports_basketball, 'Basketball', 'Movement', 'sport ball hoops'),
  TaskIconChoice(Icons.sports_martial_arts, 'Martial arts', 'Movement',
      'karate boxing judo'),
  TaskIconChoice(Icons.favorite, 'Health', 'Wellbeing', 'heart care wellness'),
  TaskIconChoice(Icons.medication, 'Medication', 'Wellbeing',
      'pill vitamins prescription medicine'),
  TaskIconChoice(
      Icons.psychology, 'Mental health', 'Wellbeing', 'therapy mind brain'),
  TaskIconChoice(Icons.air, 'Breathing', 'Wellbeing', 'breath relax calm'),
  TaskIconChoice(Icons.spa, 'Self care', 'Wellbeing', 'relax wellness pamper'),
  TaskIconChoice(
      Icons.face, 'Skin care', 'Wellbeing', 'face wash moisturizer sunscreen'),
  TaskIconChoice(Icons.clean_hands, 'Hygiene', 'Wellbeing',
      'wash hands clean teeth brush floss'),
  TaskIconChoice(
      Icons.wb_sunny, 'Morning', 'Wellbeing', 'sunlight wake routine'),
  TaskIconChoice(
      Icons.bedtime, 'Wind down', 'Wellbeing', 'night evening sleep routine'),
  TaskIconChoice(
      Icons.emoji_food_beverage, 'Tea', 'Food & drink', 'cup drink herbal'),
  TaskIconChoice(Icons.coffee, 'Coffee', 'Food & drink', 'caffeine cup drink'),
  TaskIconChoice(Icons.kitchen, 'Meal prep', 'Food & drink',
      'cook kitchen fridge planning'),
  TaskIconChoice(Icons.soup_kitchen, 'Cooking', 'Food & drink',
      'recipe soup prepare food'),
  TaskIconChoice(
      Icons.egg_alt, 'Breakfast', 'Food & drink', 'egg morning meal'),
  TaskIconChoice(
      Icons.local_pizza, 'Pizza', 'Food & drink', 'food treat takeaway'),
  TaskIconChoice(Icons.shopping_basket, 'Groceries', 'Food & drink',
      'shopping supermarket food'),
  TaskIconChoice(Icons.home, 'Home', 'Home & care', 'house chores routine'),
  TaskIconChoice(Icons.cleaning_services, 'Cleaning', 'Home & care',
      'chores tidy sweep mop'),
  TaskIconChoice(Icons.local_laundry_service, 'Laundry', 'Home & care',
      'clothes wash chores'),
  TaskIconChoice(Icons.delete_outline, 'Take out trash', 'Home & care',
      'garbage rubbish bin chores'),
  TaskIconChoice(
      Icons.recycling, 'Recycling', 'Home & care', 'recycle waste environment'),
  TaskIconChoice(
      Icons.pets, 'Pet care', 'Home & care', 'dog cat feed walk animal'),
  TaskIconChoice(
      Icons.build, 'Repairs', 'Home & care', 'maintenance tools fix diy'),
  TaskIconChoice(Icons.bathtub, 'Bath', 'Home & care', 'shower wash clean'),
  TaskIconChoice(
      Icons.bedroom_parent, 'Make bed', 'Home & care', 'bedroom tidy sheets'),
  TaskIconChoice(
      Icons.school, 'Study', 'Learning & work', 'school education class learn'),
  TaskIconChoice(Icons.translate, 'Languages', 'Learning & work',
      'language vocabulary practice learn'),
  TaskIconChoice(Icons.calculate, 'Math', 'Learning & work',
      'numbers homework mathematics'),
  TaskIconChoice(
      Icons.code, 'Coding', 'Learning & work', 'programming software computer'),
  TaskIconChoice(Icons.laptop_mac, 'Focus work', 'Learning & work',
      'computer deep work laptop'),
  TaskIconChoice(Icons.work_outline, 'Work', 'Learning & work',
      'job office business career'),
  TaskIconChoice(
      Icons.mail_outline, 'Email', 'Learning & work', 'inbox message letters'),
  TaskIconChoice(Icons.event_note, 'Planning', 'Learning & work',
      'calendar schedule organize review'),
  TaskIconChoice(
      Icons.science, 'Science', 'Learning & work', 'research lab experiment'),
  TaskIconChoice(Icons.palette, 'Art', 'Creativity', 'paint draw color sketch'),
  TaskIconChoice(Icons.brush, 'Painting', 'Creativity', 'art watercolor craft'),
  TaskIconChoice(
      Icons.music_note, 'Music', 'Creativity', 'sing practice instrument song'),
  TaskIconChoice(
      Icons.piano, 'Piano', 'Creativity', 'music keyboard practice instrument'),
  TaskIconChoice(
      Icons.camera_alt, 'Photography', 'Creativity', 'photo camera pictures'),
  TaskIconChoice(Icons.headphones, 'Listening', 'Creativity',
      'podcast music audio audiobook'),
  TaskIconChoice(
      Icons.videocam, 'Video', 'Creativity', 'film recording movie creative'),
  TaskIconChoice(Icons.content_cut, 'Crafts', 'Creativity',
      'sewing knit scissors handmade'),
  TaskIconChoice(Icons.extension, 'Puzzles', 'Creativity', 'game hobby jigsaw'),
  TaskIconChoice(Icons.phone, 'Call someone', 'People & money',
      'family friend connect telephone'),
  TaskIconChoice(Icons.forum, 'Conversation', 'People & money',
      'talk message chat connect'),
  TaskIconChoice(Icons.groups, 'Friends', 'People & money',
      'social people team community'),
  TaskIconChoice(Icons.family_restroom, 'Family', 'People & money',
      'children parent quality time'),
  TaskIconChoice(Icons.volunteer_activism, 'Kindness', 'People & money',
      'volunteer help giving gratitude'),
  TaskIconChoice(Icons.card_giftcard, 'Gifts', 'People & money',
      'birthday present celebrate'),
  TaskIconChoice(Icons.savings, 'Saving', 'People & money',
      'money budget finance piggy bank'),
  TaskIconChoice(Icons.receipt_long, 'Bills', 'People & money',
      'money expenses budget pay finance'),
  TaskIconChoice(Icons.account_balance, 'Finances', 'People & money',
      'bank investing money accounts'),
  TaskIconChoice(
      Icons.park, 'Nature', 'Outdoors', 'tree outside fresh air park'),
  TaskIconChoice(
      Icons.hiking, 'Hiking', 'Outdoors', 'trail walk mountain exercise'),
  TaskIconChoice(Icons.forest, 'Forest', 'Outdoors', 'woods trees nature'),
  TaskIconChoice(
      Icons.landscape, 'Mountains', 'Outdoors', 'adventure outdoors scenery'),
  TaskIconChoice(
      Icons.beach_access, 'Beach', 'Outdoors', 'sea ocean relax holiday'),
  TaskIconChoice(
      Icons.flight, 'Travel', 'Outdoors', 'plane trip holiday vacation'),
  TaskIconChoice(
      Icons.directions_car, 'Driving', 'Outdoors', 'car commute vehicle'),
  TaskIconChoice(Icons.star, 'Priority', 'Everyday', 'important favorite goal'),
  TaskIconChoice(
      Icons.flag, 'Goal', 'Everyday', 'milestone target achievement'),
  TaskIconChoice(Icons.check, 'Check', 'Everyday', 'complete done task'),
  TaskIconChoice(Icons.timer, 'Timer', 'Everyday', 'time stopwatch duration'),
  TaskIconChoice(Icons.alarm, 'Reminder', 'Everyday', 'clock alarm time'),
  TaskIconChoice(Icons.bolt, 'Energy', 'Everyday', 'power motivation quick'),
  TaskIconChoice(Icons.lightbulb_outline, 'Ideas', 'Everyday',
      'thinking inspiration reflect'),
  TaskIconChoice(Icons.smartphone, 'Screen time', 'Everyday',
      'phone digital detox devices'),
  TaskIconChoice(
      Icons.block, 'Avoid a habit', 'Everyday', 'stop quit break limit'),
];

final taskIcons =
    List<IconData>.unmodifiable(taskIconChoices.map((c) => c.icon));
final taskIconCategories =
    List<String>.unmodifiable(taskIconChoices.map((c) => c.category).toSet());

TaskIconChoice? taskIconFor(int codePoint) {
  for (final choice in taskIconChoices) {
    if (choice.icon.codePoint == codePoint) return choice;
  }
  return null;
}

IconData iconFor(int codePoint) => taskIconFor(codePoint)?.icon ?? Icons.flag;
