import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/profile.dart';
import '../models/story.dart';
import '../models/chat_message.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'mm_learning_lab.db');
    return await openDatabase(
      path,
      version: 6,
      onCreate: _createDb,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE profiles(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        age INTEGER NOT NULL,
        avatar TEXT NOT NULL,
        avatar_type TEXT DEFAULT 'emoji',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE game_progress(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL,
        game_type TEXT NOT NULL,
        level INTEGER NOT NULL,
        score INTEGER NOT NULL,
        completed_at TEXT NOT NULL,
        FOREIGN KEY (profile_id) REFERENCES profiles (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE math_quiz_attempts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        datetime TEXT NOT NULL,
        grade TEXT NOT NULL,
        operations TEXT NOT NULL,
        num_questions INTEGER NOT NULL,
        time_limit INTEGER NOT NULL,
        num_correct INTEGER NOT NULL,
        time_used INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE stories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        emoji TEXT,
        category TEXT NOT NULL,
        difficulty TEXT NOT NULL,
        word_of_day TEXT,
        is_user_created INTEGER DEFAULT 0,
        audio_path TEXT
      )
    ''');

    // Create chat_messages table
    await _createChatMessagesTable(db);

    // Available emoji options:
    // Boys: 👶 (baby), 🧒 (child), 👦 (boy), 🧑 (person)
    // Girls: 👶 (baby), 🧒 (child), 👧 (girl), 🧑 (person)
    // Preload default profiles
    //await _preloadDefaultProfiles(db);
    await _preloadDefaultStories(db);
  }

  /*Future<void> _preloadDefaultProfiles(Database db) async {
    // Check if profiles already exist
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM profiles'));
    if (count == 0) {
      // Add Matthew's profile
      await db.insert('profiles', {
        'name': 'Matthew',
        'age': 3,
        'avatar': '👦',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Add Madeline's profile
      await db.insert('profiles', {
        'name': 'Madeline',
        'age': 7,
        'avatar': '👧',
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }*/

  Future<void> _preloadDefaultStories(Database db) async {
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM stories'));
    if (count == 0) {
      final List<Map<String, dynamic>> initialStories = [
        {
          "title": "The Happy Duck",
          "emoji": "🦆",
          "category": "Animals",
          "difficulty": "Easy",
          "content": "Daisy is a yellow duck.\n\n"
              "She has big orange feet.\n\n"
              "Daisy loves to swim in the pond.\n\n"
              "Splash! Splash! She makes big splashes.\n\n"
              "Daisy's friends come to swim too.\n\n"
              "They all swim together.\n\n"
              "Quack! Quack! The ducks are happy.\n\n"
        },
        {
          "title": "My Red Ball",
          "emoji": "⚽",
          "category": "Adventure",
          "difficulty": "Easy",
          "content": "I have a red ball.\n\n"
              "My ball is round and bouncy.\n\n"
              "I like to throw my ball up high.\n\n"
              "I like to roll my ball on the ground.\n\n"
              "My dog likes my ball too.\n\n"
              "We play with my ball together.\n\n"
              "My red ball is my favorite toy.\n\n"
        },
        {
          "title": "Big and Small",
          "emoji": "🐘",
          "category": "Animals",
          "difficulty": "Easy",
          "content": "The elephant is big.\n\n"
              "The ant is small.\n\n"
              "The tree is big.\n\n"
              "The flower is small.\n\n"
              "The whale is big.\n\n"
              "The fish is small.\n\n"
              "Big or small, all are special.\n\n"
        },

        // Easy Level Stories (short paragraphs, simple words)
        {
          "title": "The Lost Balloon",
          "emoji": "🎈",
          "category": "Adventure",
          "difficulty": "Easy",
          "content": "Mia had a red balloon. It was her favorite toy.\n\n"
              "One windy day, Mia took her balloon to the park.\n\n"
              "Whoosh! A big wind came. It pulled the string from Mia's hand!\n\n"
              "The red balloon flew up, up, up into the sky.\n\n"
              "\"Come back!\" called Mia. She tried to catch it.\n\n"
              "But the balloon flew over the trees. It flew over the houses.\n\n"
              "Mia felt sad. Then she had a happy thought.\n\n"
              "\"My balloon will see the whole world! It will make new friends!\"\n\n"
              "That night, Mia looked at the stars. \"Goodnight, balloon. Have a happy trip!\"\n\n"
        },
        {
          "title": "Chatty and Pip",
          "emoji": "🐱",
          "category": "Animals",
          "difficulty": "Easy",
          "content": "Chatty was a curious cat with soft orange fur.\n\n"
              "One sunny morning, Chatty found something shiny in the garden.\n\n"
              "It was a small round pebble. Chatty pawed at it gently.\n\n"
              "Suddenly, a tiny ant crawled out from under the pebble.\n\n"
              "\"Hello there!\" said Chatty. \"I'm Chatty. What's your name?\"\n\n"
              "\"I'm Pip,\" said the ant in a tiny voice. Pip was a little scared.\n\n"
              "\"Don't worry,\" said Chatty. \"I won't hurt you. Let's be friends!\"\n\n"
              "Chatty and Pip had a fun day together. They climbed over rocks.\n\n"
              "They hid under leaves. They watched colorful butterflies dance.\n\n"
              "When the sun began to set, they sat together and talked about their day.\n\n"
              "Chatty and Pip became the best of friends.\n\n"
        },
        {
          "title": "The Rainbow Slide",
          "emoji": "🌈",
          "category": "Fantasy",
          "difficulty": "Easy",
          "content": "It rained all day. Lily watched from her window.\n\n"
              "When the rain stopped, a beautiful rainbow appeared in the sky.\n\n"
              "\"I wish I could slide down that rainbow,\" said Lily.\n\n"
              "Suddenly, the rainbow began to sparkle and shine!\n\n"
              "A magical slide appeared, leading right to Lily's window.\n\n"
              "Lily climbed onto the rainbow slide. It felt warm and tingly.\n\n"
              "Whoosh! She slid down through the colors.\n\n"
              "Red, orange, yellow, green, blue, and purple flew past her.\n\n"
              "At the bottom, Lily landed in a field of flowers.\n\n"
              "The flowers giggled and tickled her toes. They sang happy songs.\n\n"
              "\"Thank you for the slide,\" Lily called to the rainbow.\n\n"
              "\"I'll come back after the next rain!\"\n\n"
        },
        {
          "title": "Brave Little Mouse",
          "emoji": "🐭",
          "category": "Animals",
          "difficulty": "Easy",
          "content": "Timmy was a tiny gray mouse. He lived in a hole in the wall.\n\n"
              "Next door lived a big dog named Buddy.\n\n"
              "Timmy wanted to meet Buddy, but he was nervous.\n\n"
              "\"Buddy is so big, and I am so small,\" thought Timmy.\n\n"
              "One morning, Timmy took a deep breath. \"I can be brave!\"\n\n"
              "He stepped out of his hole and squeaked, \"Hello!\"\n\n"
              "Buddy turned and saw the little mouse. He wagged his tail.\n\n"
              "\"Hello, little friend!\" said Buddy in a gentle voice.\n\n"
              "Timmy and Buddy played tag in the garden.\n\n"
              "They shared a snack under the big oak tree.\n\n"
              "They watched puffy clouds float by in the blue sky.\n\n"
              "\"Being brave is wonderful,\" thought Timmy. \"Now I have a new friend!\"\n\n"
        },

        // Medium Level Stories (longer paragraphs, more complex words)
        {
          "title": "Rocket to the Moon",
          "emoji": "🚀",
          "category": "Space",
          "difficulty": "Medium",
          "content": "Ben loved space. He had books about planets and stars. He watched rockets launch on TV. Every night, he looked at the moon and wondered what it would be like to go there.\n\n"
              "One rainy Saturday, Ben decided to build his own rocket ship. He collected cardboard boxes from the garage. He found silver paint in Dad's workshop. He even made a space helmet from an old fishbowl.\n\n"
              "Ben set up his rocket in the backyard. He climbed inside and put on his helmet. \"3... 2... 1... BLAST OFF!\" he shouted.\n\n"
              "In his imagination, the rocket zoomed up through the clouds. It flew past twinkling stars and colorful planets. Ben waved at some friendly green aliens flying by in their spaceship.\n\n"
              "Finally, Ben's rocket landed on the moon with a gentle bump. He stepped out and bounced across the dusty surface. \"The moon has much less gravity than Earth,\" Ben remembered from his books.\n\n"
              "Ben planted a flag with his name on it. He discovered a field of moon cheese, which sparkled like diamonds. He made footprints in the gray moon dust.\n\n"
              "When it was time to go home, Ben took one last look around. \"I'll come back to visit you, Moon,\" he promised.\n\n"
              "Back in his backyard, Ben told his teddy bear all about his exciting adventure in space. Ben knew that someday, he might be a real astronaut. But until then, his imagination could take him anywhere.\n\n"
        },
        {
          "title": "The Magic Hat",
          "emoji": "🎩",
          "category": "Fantasy",
          "difficulty": "Medium",
          "content": "Max found a dusty old hat in the attic. It was tall and black with a red ribbon around it. It looked like a magician's hat from the movies.\n\n"
              "Max brushed off the dust and placed the hat on his head. It was too big and fell over his eyes. But suddenly, Max felt a strange tingling in his toes that spread all the way up to his fingertips.\n\n"
              "\"Please,\" Max whispered, not knowing what he was asking for. To his amazement, something moved inside the hat. He took it off, and out hopped a fluffy white rabbit!\n\n"
              "\"Wow!\" gasped Max. The rabbit twitched its nose, then hopped around Max's room three times before disappearing with a small *pop*.\n\n"
              "Max put the hat on again. \"Please,\" he said, more confidently this time. He removed the hat, and a beautiful rainbow-colored scarf floated out, hovering in the air before settling onto Max's bed.\n\n"
              "The next day, Max invited his friends over for a magic show. He wore a black cape that his mom helped him make from an old curtain. With the magic hat on his head, Max performed amazing tricks.\n\n"
              "From the hat came flowers, shiny coins, and even a tiny meowing kitten that his friend Sophia got to keep. Everyone clapped and cheered for Magnificent Max the Magician.\n\n"
              "That night, as Max carefully placed the hat on his shelf, he realized something important. The real magic wasn't just in the hat—it was in the smiles and wonder he had created for his friends.\n\n"
        },
        {
          "title": "Star Picnic",
          "emoji": "⭐",
          "category": "Fantasy",
          "difficulty": "Medium",
          "content": "Zoe couldn't sleep. The night was warm, and the stars looked especially bright through her window. She picked up her teddy bear, Mr. Buttons, and whispered, \"Let's have a picnic under the stars!\"\n\n"
              "Quietly, so she wouldn't wake her parents, Zoe packed her little basket. She put in cookies from the kitchen, a thermos of warm milk, and a blanket. Then she and Mr. Buttons tiptoed out to the backyard.\n\n"
              "The grass felt cool under Zoe's bare feet. She spread the blanket on a perfect spot where they could see the whole sky. Zoe and Mr. Buttons lay down and looked up at the twinkling stars.\n\n"
              "\"Look! A shooting star!\" Zoe pointed as a bright light streaked across the sky. Then another one flashed by. Zoe counted the shooting stars as she munched on cookies and sipped her milk.\n\n"
              "Suddenly, Zoe heard a soft \"Hoo, hoo\" sound. A large owl with feathers the color of moonlight landed on the fence. Its round eyes seemed to glow in the dark.\n\n"
              "\"Hello,\" said Zoe. \"Would you like to join our picnic?\"\n\n"
              "The owl hooted softly again and began to sing a gentle, soothing melody. It was the most beautiful lullaby Zoe had ever heard.\n\n"
              "As the owl sang, Zoe made a wish on the brightest star in the sky. She wished for sweet dreams, not just for tonight, but forever. Zoe's eyes grew heavy, and she snuggled close to Mr. Buttons.\n\n"
              "The last thing Zoe remembered was the owl's lullaby and the feeling of being safe and happy under the magical night sky filled with stars.\n\n"
        },

        // Hard Level Stories (complex narrative, more vocabulary)
        {
          "title": "The Time-Traveling Watch",
          "emoji": "⌚",
          "category": "Adventure",
          "difficulty": "Hard",
          "content": "Emma was helping her grandfather clean out his dusty attic when she found an unusual pocket watch. It was made of gleaming brass with strange symbols etched around its face, and it had not one but three winding knobs on the side.\n\n"
              "\"What's this, Grandpa?\" Emma asked, holding up the watch. A mysterious smile crossed her grandfather's face.\n\n"
              "\"Ah, I've been wondering where that went,\" he said softly. \"It's very special. Try winding the middle knob.\"\n\n"
              "Curious, Emma turned the knob. The hands of the watch began to spin rapidly backward. The air around her shimmered and wavered like heat rising from hot pavement. Suddenly, everything went dark.\n\n"
              "When Emma could see again, she gasped. She was standing in blazing sunlight, surrounded by hundreds of people in strange clothing. Massive stone blocks were being hauled up ramps by teams of workers. In the distance, a half-finished pyramid rose against a cloudless sky.\n\n"
              "\"Ancient Egypt!\" Emma whispered in amazement. She watched, fascinated, as the pyramid builders worked, using only simple tools and incredible ingenuity to create one of the world's greatest wonders.\n\n"
              "Before she could explore further, the watch began to vibrate. Emma looked down and saw the hands spinning again. Once more the world blurred around her.\n\n"
              "This time, Emma found herself in a lush, steamy jungle. A massive creature with a long neck moved slowly through the trees, munching on leaves. \"A brachiosaurus!\" Emma exclaimed, recognizing the dinosaur from her science books.\n\n"
              "In the days that followed, Emma discovered that the watch could take her anywhere in time. She visited Leonardo da Vinci's workshop and watched him paint the Mona Lisa. She saw the first electric lights illuminate a city street. She even glimpsed the gleaming silver buildings of a future city, where flying cars zoomed between skyscrapers.\n\n"
              "With each journey, Emma learned something new. She discovered how the Egyptians used mathematics and astronomy to build the pyramids. She observed how dinosaurs cared for their young. She saw how Leonardo's curiosity led to inventions centuries ahead of his time.\n\n"
              "When Emma finally returned to her grandfather's attic, no time had passed at all. Her grandfather was watching her with that same mysterious smile.\n\n"
              "\"Did you have a good trip?\" he asked.\n\n"
              "Emma grinned. \"The best,\" she said. \"But I've learned that the most amazing adventure is learning about our world—past, present, and future.\"\n\n"
              "Her grandfather nodded. \"That's exactly why the watch chose you.\"\n\n"
        },
        {
          "title": "The Secret Garden",
          "emoji": "🌺",
          "category": "Nature",
          "difficulty": "Hard",
          "content": "Behind Lily's new house stood an ancient stone wall covered in thick ivy. Everyone said it was just the boundary of the property, but Lily noticed something odd: a small archway, almost hidden by the tangled plants.\n\n"
              "One spring morning, while her parents were unpacking boxes, Lily decided to investigate. She carefully pushed aside the ivy and discovered a rusty iron gate. It creaked loudly as she pushed it open, revealing a hidden garden beyond.\n\n"
              "Lily stepped through the gate and gasped. Inside was the most extraordinary garden she had ever seen. Flowers of every color imaginable grew in dazzling patterns. Butterflies fluttered from bloom to bloom, and the air was filled with sweet fragrance.\n\n"
              "\"Hello there!\" called a cheerful voice. Lily jumped in surprise. A tall rose bush nearby was moving, even though there was no wind. Then Lily realized: the roses themselves were speaking!\n\n"
              "\"Don't be frightened,\" said a deep red rose. \"We don't often get visitors anymore. What's your name?\"\n\n"
              "\"L-Lily,\" she stammered. \"The flowers in my garden at home don't talk.\"\n\n"
              "\"Most flowers don't,\" agreed a cluster of purple tulips nearby. \"But this garden is special. It was created long ago by a woman who loved plants so much that she found a way to communicate with them. Her magic still lives in this soil.\"\n\n"
              "Over the next few hours, Lily met all the garden's inhabitants. The roses told grand stories of ancient times when knights and princesses visited the garden. The tulips sang beautiful lullabies they had learned from the old woman. The daisies, playful and energetic, taught Lily to play hide-and-seek among the flower beds.\n\n"
              "Lily noticed that parts of the garden were overgrown, with weeds choking some of the flowers. \"No one has tended to us for many years,\" explained a wise old sunflower. \"We do our best, but we need human hands to truly thrive.\"\n\n"
              "\"I'll help you,\" Lily promised. \"I'll come every day. I'll bring water when it's dry and clear away the weeds.\"\n\n"
              "True to her word, Lily visited the garden whenever she could. Under her care, the garden flourished even more. The flowers grew taller and brighter. New buds appeared in bare patches. The garden seemed to pulse with joyful energy.\n\n"
              "In return, the flowers taught Lily the secret language of nature—how to tell when rain was coming by the way leaves curled, how to know which plants could heal a cut or soothe a bee sting, how all living things were connected in a delicate balance.\n\n"
              "\"You must keep our secret,\" the flowers told her. \"Not everyone would understand our magic.\"\n\n"
              "Lily agreed. Some secrets were too precious to share with just anyone. But she did bring her little brother to meet the flowers, and later, her best friend. The garden welcomed those with open hearts and gentle hands.\n\n"
              "And so the secret garden bloomed once more, teaching each visitor about the importance of nurturing all living things and protecting the precious natural world around us.\n\n"
        },

        // Additional easy stories with clear paragraph breaks
        {
          "title": "The Bus Adventure",
          "emoji": "🚌",
          "category": "Adventure",
          "difficulty": "Easy",
          "content": "Tommy and his friends waited for the yellow school bus.\n\n"
              "\"Here it comes!\" shouted Tommy.\n\n"
              "The bus had big round wheels that went round and round.\n\n"
              "The doors opened with a squeak. The children climbed aboard.\n\n"
              "Tommy sat by the window. He could see everything outside.\n\n"
              "The wipers went swish, swish, swish in the light rain.\n\n"
              "The horn went beep, beep, beep at the railroad crossing.\n\n"
              "Tommy and his friends sang songs all the way to school.\n\n"
              "They saw a beautiful rainbow arch across the sky.\n\n"
              "When they arrived at school, Tommy couldn't wait to tell his teacher.\n\n"
              "\"The bus is like a moving classroom!\" he said with a big smile.\n\n"
              "It was the best bus ride ever.\n\n"
        },
        {
          "title": "Splash Time",
          "emoji": "🛁",
          "category": "Adventure",
          "difficulty": "Easy",
          "content": "It was bath time for Emma.\n\n"
              "Mom filled the tub with warm water.\n\n"
              "Emma put her yellow rubber ducky in the water.\n\n"
              "The ducky floated on top. Bobbing up and down.\n\n"
              "Splash! Emma hit the water with her hand.\n\n"
              "The ducky bounced on the tiny waves.\n\n"
              "Mom helped Emma wash her hair.\n\n"
              "They sang the special shampoo song together.\n\n"
              "\"Scrub, scrub, scrub your hair. Make it clean and bright!\"\n\n"
              "After the bath, Emma was squeaky clean.\n\n"
              "She gave her ducky a goodnight kiss.\n\n"
              "Then she went to bed, dreaming of swimming like her ducky.\n\n"
        },
        {
          "title": "Sharing is Caring",
          "emoji": "🍪",
          "category": "Adventure",
          "difficulty": "Easy",
          "content": "Lily got a big box of cookies for her birthday.\n\n"
              "There were chocolate chip, sugar, and oatmeal cookies.\n\n"
              "Lily looked at all the yummy cookies.\n\n"
              "\"I have so many,\" she thought. \"I should share them.\"\n\n"
              "She went to find her friends.\n\n"
              "She gave a chocolate chip cookie to Tommy.\n\n"
              "She gave a sugar cookie to Emma.\n\n"
              "She gave an oatmeal cookie to Max.\n\n"
              "They all sat together on the grass.\n\n"
              "\"These cookies are delicious!\" said Tommy.\n\n"
              "They sang a happy song while they ate their cookies.\n\n"
              "\"Sharing makes everything more fun!\" they sang.\n\n"
              "Lily felt warm and happy inside.\n\n"
              "Sharing her cookies made everyone smile, including her.\n\n"
        },

        // Additional medium stories with clear structure
        {
          "title": "Marina's Treasure",
          "emoji": "🧜‍♀️",
          "category": "Fantasy",
          "difficulty": "Medium",
          "content": "Marina was a young mermaid with a shimmering blue tail and long flowing hair. She lived in a coral palace deep under the sea with her family.\n\n"
              "Unlike other mermaids who collected pearls and shiny shells, Marina loved to explore sunken ships. These old wooden vessels rested on the ocean floor, full of mysterious treasures from the human world above.\n\n"
              "\"Be careful of those human things,\" her mother always warned. \"They don't belong in our world.\" But Marina couldn't resist their strange beauty and wonder.\n\n"
              "One sunny morning, while exploring a newly sunken ship, Marina discovered something special hidden in a small wooden chest. It was a beautiful music box decorated with seashells and starfish.\n\n"
              "Curious, Marina opened the lid. A sweet melody began to play, unlike any sound Marina had ever heard before. The music seemed to dance through the water around her.\n\n"
              "To Marina's amazement, nearby fish began to swim in graceful patterns. A group of seahorses swayed in rhythm to the tune. Even the grumpy old crab who lived under a rock nearby came out to listen.\n\n"
              "\"This music is magical!\" Marina exclaimed as she watched a circle of tiny silver fish twirl above the music box.\n\n"
              "Marina realized that this treasure wasn't meant to be kept hidden in her collection. She carried the music box to the center of the reef where all the sea creatures could hear it.\n\n"
              "Soon, the entire ocean seemed filled with the beautiful melody. Dolphins performed flips and spins. Jellyfish pulsed in time with the rhythm. Even the giant whales came to listen and sing along in their deep, rumbling voices.\n\n"
              "Marina's father, the king of the merpeople, swam up to her. \"You've discovered something truly special, daughter,\" he said with a smile. \"The best treasures aren't the ones we keep for ourselves, but the ones that bring joy to others.\"\n\n"
              "From that day on, Marina played the music box every evening at sunset. The melody brought together all the creatures of the sea in harmony and friendship.\n\n"
              "And Marina learned that sharing something special is far better than keeping it all to yourself.\n\n"
        },
        {
          "title": "Leo's Night Light",
          "emoji": "🦁",
          "category": "Animals",
          "difficulty": "Medium",
          "content": "Leo was a young lion with a golden mane and a bushy tail. All the animals in the jungle thought Leo must be very brave because lions are known as the kings of the jungle.\n\n"
              "But Leo had a secret. He was afraid of the dark. When night fell and shadows filled the jungle, Leo's heart would beat fast and his paws would shake.\n\n"
              "\"A lion shouldn't be afraid of anything,\" he told himself. But no matter how hard he tried, he couldn't make the fear go away.\n\n"
              "Leo's friends tried to help. Giraffe suggested standing tall to see above the darkness. Monkey gave him a special branch to hold. Elephant taught him to make loud sounds to scare away frightening thoughts. But nothing worked.\n\n"
              "One particularly dark night, Leo heard a small squeaking sound outside his den. Peeking out cautiously, he saw a tiny field mouse scurrying around in circles.\n\n"
              "\"What's wrong?\" Leo asked, trying to keep his voice from trembling in the darkness.\n\n"
              "\"I'm lost,\" sobbed the mouse. \"My home is on the other side of the tall grass, but it's so dark I can't find my way. I'm scared I'll never see my family again.\"\n\n"
              "Leo looked at the tiny mouse, shivering with fear. Something stirred inside him—something stronger than his own fear.\n\n"
              "\"I'll help you get home,\" Leo said. Taking a deep breath, he stepped out of his den and into the darkness.\n\n"
              "As they walked through the night jungle, Leo focused on helping the mouse instead of his own fear. He listened for danger, watched for obstacles, and guided the small creature safely through the tall grass.\n\n"
              "When they finally reached the mouse's home, the little creature squeaked with joy. \"Thank you, brave lion! You're not afraid of anything!\"\n\n"
              "Leo smiled. \"Actually, I am afraid of the dark. But I learned something tonight. Being brave doesn't mean you're never scared. It means doing what's right even when you are scared.\"\n\n"
              "After that night, Leo still felt afraid sometimes. But he remembered the little mouse and how helping others had made him stronger than his fears.\n\n"
              "The end."
        }
      ];

      for (final story in initialStories) {
        await db.insert('stories', story);
      }
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Upgrading database from $oldVersion to $newVersion');

    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS math_quiz_attempts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          datetime TEXT NOT NULL,
          grade TEXT NOT NULL,
          operations TEXT NOT NULL,
          num_questions INTEGER NOT NULL,
          time_limit INTEGER NOT NULL,
          num_correct INTEGER NOT NULL,
          time_used INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      // Add audio_path column to stories table
      await db.execute('ALTER TABLE stories ADD COLUMN audio_path TEXT');
    }
    if (oldVersion < 4) {
      // Create chat_messages table for AI conversation feature
      await _createChatMessagesTable(db);
    }

    // For version 5, ensure chat_messages table exists regardless of previous versions
    if (oldVersion < 5) {
      // First check if the table exists
      final tableCheck = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='chat_messages'");

      if (tableCheck.isEmpty) {
        print('Creating missing chat_messages table');
        await _createChatMessagesTable(db);
      } else {
        print('chat_messages table already exists');
      }
    }

    // For version 6, add avatar_type column to profiles table
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE profiles ADD COLUMN avatar_type TEXT DEFAULT "emoji"');
    }
  }

  // Helper method to create chat_messages table
  Future<void> _createChatMessagesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message TEXT NOT NULL,
        is_user_message INTEGER NOT NULL,
        audio_path TEXT,
        timestamp TEXT NOT NULL,
        profile_id INTEGER,
        FOREIGN KEY (profile_id) REFERENCES profiles (id)
      )
    ''');
  }

  // Profile CRUD operations
  Future<int> insertProfile(Profile profile) async {
    final db = await database;
    return await db.insert('profiles', profile.toMap());
  }

  Future<List<Profile>> getProfiles() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('profiles');
    return List.generate(maps.length, (i) => Profile.fromMap(maps[i]));
  }

  Future<Profile?> getProfile(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'profiles',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Profile.fromMap(maps.first);
  }

  Future<int> updateProfile(Profile profile) async {
    final db = await database;
    return await db.update(
      'profiles',
      profile.toMap(),
      where: 'id = ?',
      whereArgs: [profile.id],
    );
  }

  Future<int> deleteProfile(int id) async {
    final db = await database;
    return await db.delete(
      'profiles',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteDatabase() async {
    String path = join(await getDatabasesPath(), 'mm_learning_lab.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  // Math quiz logging
  Future<void> insertMathQuizAttempt({
    required String grade,
    required String operations,
    required int numQuestions,
    required int timeLimit,
    required int numCorrect,
    required int timeUsed,
  }) async {
    final db = await database;
    await db.insert('math_quiz_attempts', {
      'datetime': DateTime.now().toIso8601String(),
      'grade': grade,
      'operations': operations,
      'num_questions': numQuestions,
      'time_limit': timeLimit,
      'num_correct': numCorrect,
      'time_used': timeUsed,
    });
  }

  Future<List<Map<String, dynamic>>> getMathQuizAttempts() async {
    final db = await database;
    return await db.query('math_quiz_attempts', orderBy: 'datetime DESC');
  }

  // Story CRUD operations
  Future<int> insertStory(Story story) async {
    final db = await database;
    return await db.insert('stories', story.toMap());
  }

  Future<int> updateStory(Story story) async {
    final db = await database;
    return await db.update(
      'stories',
      story.toMap(),
      where: 'id = ?',
      whereArgs: [story.id],
    );
  }

  Future<int> deleteStory(int id) async {
    final db = await database;
    return await db.delete(
      'stories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Chat Messages CRUD operations
  Future<int> insertChatMessage(ChatMessage message) async {
    final db = await database;
    return await db.insert('chat_messages', message.toMap());
  }

  Future<int> updateChatMessage(ChatMessage message) async {
    final db = await database;
    return await db.update(
      'chat_messages',
      message.toMap(),
      where: 'id = ?',
      whereArgs: [message.id],
    );
  }

  Future<List<ChatMessage>> getChatMessages({int? profileId, int limit = 100}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps;

    if (profileId != null) {
      maps = await db.query(
        'chat_messages',
        where: 'profile_id = ?',
        whereArgs: [profileId],
        orderBy: 'timestamp DESC',
        limit: limit,
      );
    } else {
      maps = await db.query(
        'chat_messages',
        orderBy: 'timestamp DESC',
        limit: limit,
      );
    }

    final messages = List.generate(maps.length, (i) => ChatMessage.fromMap(maps[i]));
    return messages.reversed.toList(); // Return in chronological order
  }

  Future<int> deleteAllChatMessages({int? profileId}) async {
    final db = await database;
    if (profileId != null) {
      return await db.delete(
        'chat_messages',
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
    } else {
      return await db.delete('chat_messages');
    }
  }

  Future<int> deleteChatMessagesBefore(DateTime date, {int? profileId}) async {
    final db = await database;
    String whereClause = 'timestamp < ?';
    List<dynamic> whereArgs = [date.toIso8601String()];

    if (profileId != null) {
      whereClause += ' AND profile_id = ?';
      whereArgs.add(profileId);
    }

    return await db.delete(
      'chat_messages',
      where: whereClause,
      whereArgs: whereArgs,
    );
  }

  Future<int> clearChatMessagesAudioFiles() async {
    final db = await database;
    // We're not actually deleting the files here, just the references
    // The actual file deletion should be handled separately
    return await db.update(
      'chat_messages',
      {'audio_path': null},
      where: 'audio_path IS NOT NULL',
    );
  }

  // Add a method to check database integrity and reset if needed
  Future<bool> checkAndRepairDatabase() async {
    try {
      final db = await database;

      // Check if chat_messages table exists
      final tableCheck = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='chat_messages'");

      if (tableCheck.isEmpty) {
        print('chat_messages table missing, resetting database');
        await resetDatabase();
        return true;
      }

      print('Database integrity check passed');
      return false;
    } catch (e) {
      print('Error checking database: $e');
      await resetDatabase();
      return true;
    }
  }

  // Method to completely reset the database
  Future<void> resetDatabase() async {
    try {
      // Close the current database connection
      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      // Delete the database file
      String path = join(await getDatabasesPath(), 'mm_learning_lab.db');
      await databaseFactory.deleteDatabase(path);

      print('Database deleted, will be recreated on next access');

      // Reinitialize database (this will trigger onCreate)
      _database = await _initDatabase();
    } catch (e) {
      print('Error resetting database: $e');
    }
  }
}
