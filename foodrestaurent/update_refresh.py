import os
import re

import_statement = "import 'package:food_user_application/core/widgets/app_refresh_indicator.dart';\n"

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    if 'RefreshIndicator(' in content and 'AppRefreshIndicator(' not in content:
        # Check if import is already there
        if import_statement not in content:
            # Find the last import statement and add it after
            imports_end = 0
            lines = content.split('\n')
            for i, line in enumerate(lines):
                if line.startswith('import '):
                    imports_end = i
            
            lines.insert(imports_end + 1, import_statement.strip())
            content = '\n'.join(lines)
            
        content = content.replace('RefreshIndicator(', 'AppRefreshIndicator(')
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated {filepath}")

def main():
    lib_dir = r"c:\Users\rishi\OneDrive\Desktop\Flutter_food\flutter-food-Restaurant\lib\features"
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                process_file(filepath)

if __name__ == "__main__":
    main()
