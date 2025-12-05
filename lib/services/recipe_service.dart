import '../models/inventory_item.dart';
import 'database_service.dart';

class Recipe {
  final String id;
  final String name;
  final String description;
  final List<String> ingredients;
  final List<String> instructions;
  final int prepTime; // in minutes
  final int cookTime; // in minutes
  final int servings;
  final String difficulty;
  final String category;
  final String? imageUrl;
  final double rating;

  Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.ingredients,
    required this.instructions,
    required this.prepTime,
    required this.cookTime,
    required this.servings,
    required this.difficulty,
    required this.category,
    this.imageUrl,
    this.rating = 0.0,
  });

  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      ingredients: List<String>.from(map['ingredients']),
      instructions: List<String>.from(map['instructions']),
      prepTime: map['prepTime'],
      cookTime: map['cookTime'],
      servings: map['servings'],
      difficulty: map['difficulty'],
      category: map['category'],
      imageUrl: map['imageUrl'],
      rating: (map['rating'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'ingredients': ingredients,
      'instructions': instructions,
      'prepTime': prepTime,
      'cookTime': cookTime,
      'servings': servings,
      'difficulty': difficulty,
      'category': category,
      'imageUrl': imageUrl,
      'rating': rating,
    };
  }
}

class RecipeService {
  final DatabaseService _databaseService;

  RecipeService(this._databaseService);

  // Local recipe database (could be loaded from JSON or SQLite)
  static final List<Recipe> _localRecipes = [
    Recipe(
      id: '1',
      name: 'Vegetable Stir Fry',
      description: 'Quick and healthy vegetable stir fry using fresh produce',
      ingredients: [
        '2 carrots, sliced',
        '1 bell pepper, sliced',
        '1 onion, sliced',
        '2 cloves garlic, minced',
        '1 tbsp soy sauce',
        '1 tbsp vegetable oil',
        'Salt and pepper to taste',
      ],
      instructions: [
        'Heat oil in a large pan or wok',
        'Add garlic and stir for 30 seconds',
        'Add vegetables and stir fry for 5-7 minutes',
        'Add soy sauce and seasoning',
        'Cook for another 2 minutes',
        'Serve hot with rice or noodles',
      ],
      prepTime: 10,
      cookTime: 10,
      servings: 2,
      difficulty: 'Easy',
      category: 'Vegetarian',
      rating: 4.5,
    ),
    Recipe(
      id: '2',
      name: 'Egg Fried Rice',
      description: 'Simple fried rice using leftover rice and eggs',
      ingredients: [
        '2 cups cooked rice',
        '2 eggs, beaten',
        '1 carrot, diced',
        '1/2 cup peas',
        '2 tbsp soy sauce',
        '1 tbsp vegetable oil',
        '2 green onions, chopped',
      ],
      instructions: [
        'Heat oil in a large pan',
        'Scramble eggs and set aside',
        'Add carrots and peas, cook for 3 minutes',
        'Add rice and stir well',
        'Add cooked eggs and soy sauce',
        'Mix well and garnish with green onions',
      ],
      prepTime: 10,
      cookTime: 10,
      servings: 2,
      difficulty: 'Easy',
      category: 'Quick Meal',
      rating: 4.3,
    ),
    Recipe(
      id: '3',
      name: 'Tomato Pasta',
      description: 'Classic pasta with simple tomato sauce',
      ingredients: [
        '200g pasta',
        '4 tomatoes, diced',
        '2 cloves garlic, minced',
        '1 onion, chopped',
        '1 tbsp olive oil',
        'Salt and pepper to taste',
        'Fresh basil (optional)',
      ],
      instructions: [
        'Cook pasta according to package instructions',
        'Heat oil in a pan, add garlic and onion',
        'Add tomatoes and cook for 10 minutes',
        'Season with salt and pepper',
        'Mix sauce with cooked pasta',
        'Garnish with fresh basil if available',
      ],
      prepTime: 5,
      cookTime: 15,
      servings: 2,
      difficulty: 'Easy',
      category: 'Italian',
      rating: 4.2,
    ),
    Recipe(
      id: '4',
      name: 'Vegetable Soup',
      description: 'Hearty vegetable soup using various vegetables',
      ingredients: [
        '2 carrots, chopped',
        '2 potatoes, chopped',
        '1 onion, chopped',
        '2 celery stalks, chopped',
        '4 cups vegetable broth',
        '1 tbsp olive oil',
        'Salt and pepper to taste',
      ],
      instructions: [
        'Heat oil in a large pot',
        'Sauté onions until translucent',
        'Add carrots, potatoes, and celery',
        'Add vegetable broth and bring to boil',
        'Reduce heat and simmer for 20 minutes',
        'Season with salt and pepper',
        'Serve hot with bread',
      ],
      prepTime: 15,
      cookTime: 25,
      servings: 4,
      difficulty: 'Easy',
      category: 'Soup',
      rating: 4.4,
    ),
    Recipe(
      id: '5',
      name: 'Banana Bread',
      description: 'Moist banana bread using ripe bananas',
      ingredients: [
        '3 ripe bananas',
        '1 1/2 cups flour',
        '1/2 cup sugar',
        '1/4 cup butter, melted',
        '1 egg',
        '1 tsp baking soda',
        '1 tsp vanilla extract',
      ],
      instructions: [
        'Preheat oven to 175°C (350°F)',
        'Mash bananas in a bowl',
        'Mix in melted butter and egg',
        'Add dry ingredients and mix',
        'Pour into greased loaf pan',
        'Bake for 50-60 minutes',
        'Cool before slicing',
      ],
      prepTime: 15,
      cookTime: 60,
      servings: 8,
      difficulty: 'Medium',
      category: 'Bakery',
      rating: 4.6,
    ),
  ];

  Future<List<Recipe>> getRecipesForExpiringItems(List<InventoryItem> items) async {
    if (items.isEmpty) return [];

    // Extract keywords from item names
    final keywords = items.map((item) {
      final name = item.name.toLowerCase();
      return name.split(' ').first; // Get first word as keyword
    }).toSet();

    // Find recipes that match keywords
    final matchedRecipes = _localRecipes.where((recipe) {
      // Check recipe name for keywords
      final recipeName = recipe.name.toLowerCase();
      if (keywords.any((keyword) => recipeName.contains(keyword))) {
        return true;
      }

      // Check recipe description for keywords
      final recipeDesc = recipe.description.toLowerCase();
      if (keywords.any((keyword) => recipeDesc.contains(keyword))) {
        return true;
      }

      // Check recipe ingredients for keywords
      for (final ingredient in recipe.ingredients) {
        if (keywords.any((keyword) => ingredient.toLowerCase().contains(keyword))) {
          return true;
        }
      }

      return false;
    }).toList();

    return matchedRecipes;
  }

  Future<List<Recipe>> getRecipesByCategory(String category) async {
    return _localRecipes
        .where((recipe) => recipe.category.toLowerCase().contains(category.toLowerCase()))
        .toList();
  }

  Future<List<Recipe>> searchRecipes(String query) async {
    if (query.isEmpty) return _localRecipes;

    final lowercaseQuery = query.toLowerCase();

    return _localRecipes.where((recipe) {
      return recipe.name.toLowerCase().contains(lowercaseQuery) ||
          recipe.description.toLowerCase().contains(lowercaseQuery) ||
          recipe.category.toLowerCase().contains(lowercaseQuery) ||
          recipe.ingredients.any((ingredient) => ingredient.toLowerCase().contains(lowercaseQuery));
    }).toList();
  }

  Future<List<Recipe>> getQuickRecipes({int maxTime = 30}) async {
    return _localRecipes
        .where((recipe) => recipe.prepTime + recipe.cookTime <= maxTime)
        .toList();
  }

  Future<List<Recipe>> getEasyRecipes() async {
    return _localRecipes
        .where((recipe) => recipe.difficulty == 'Easy')
        .toList();
  }

  Future<Recipe?> getRecipeById(String id) async {
    return _localRecipes.firstWhere(
          (recipe) => recipe.id == id,
      orElse: () => throw Exception('Recipe not found'),
    );
  }

  Future<List<Recipe>> getRecommendedRecipes() async {
    // Get expiring items
    final expiringItems = await _databaseService.getExpiringSoonItems();

    if (expiringItems.isEmpty) {
      // Return quick recipes if no expiring items
      return getQuickRecipes();
    }

    // Get recipes for expiring items
    return await getRecipesForExpiringItems(expiringItems);
  }

  Future<List<String>> getAllCategories() async {
    final categories = _localRecipes.map((recipe) => recipe.category).toSet();
    return categories.toList()..sort();
  }

  Future<List<Recipe>> getRecipesByIngredients(List<String> availableIngredients) async {
    final lowercaseIngredients = availableIngredients.map((ing) => ing.toLowerCase()).toList();

    return _localRecipes.where((recipe) {
      // Count how many ingredients are available
      final availableCount = recipe.ingredients.where((ingredient) {
        final ingredientLower = ingredient.toLowerCase();
        return lowercaseIngredients.any((available) => ingredientLower.contains(available));
      }).length;

      // Recipe is suitable if at least 60% of ingredients are available
      return availableCount >= (recipe.ingredients.length * 0.6);
    }).toList();
  }

  Future<List<Recipe>> getVegetarianRecipes() async {
    final vegetarianKeywords = ['vegetable', 'pasta', 'rice', 'salad', 'soup'];
    final meatKeywords = ['chicken', 'beef', 'pork', 'meat', 'fish', 'seafood'];

    return _localRecipes.where((recipe) {
      final allText = '${recipe.name} ${recipe.description} ${recipe.ingredients.join(' ')}'.toLowerCase();

      // Check if contains meat keywords
      final hasMeat = meatKeywords.any((keyword) => allText.contains(keyword));

      return !hasMeat;
    }).toList();
  }

  Future<void> rateRecipe(String recipeId, double rating) async {
    // In a real app, this would save to a database
    final index = _localRecipes.indexWhere((recipe) => recipe.id == recipeId);
    if (index != -1) {
      // Update the recipe rating (simple average)
      final recipe = _localRecipes[index];
      final newRating = (recipe.rating + rating) / 2;
      _localRecipes[index] = Recipe(
        id: recipe.id,
        name: recipe.name,
        description: recipe.description,
        ingredients: recipe.ingredients,
        instructions: recipe.instructions,
        prepTime: recipe.prepTime,
        cookTime: recipe.cookTime,
        servings: recipe.servings,
        difficulty: recipe.difficulty,
        category: recipe.category,
        imageUrl: recipe.imageUrl,
        rating: newRating,
      );
    }
  }
}