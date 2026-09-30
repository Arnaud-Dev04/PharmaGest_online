import os
import re

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Si le fichier ne contient pas catch (e), on l'ignore
    if 'catch (e)' not in content:
        return

    # S'il l'a, on vérifie s'il utilise déjà ErrorHelper
    if 'ErrorHelper' not in content:
        # Ajouter l'import
        # Trouver le dernier import
        import_match = list(re.finditer(r"^import\s+['\"].*?['\"];$", content, re.MULTILINE))
        if import_match:
            last_import = import_match[-1]
            insert_pos = last_import.end()
            content = content[:insert_pos] + "\nimport 'package:frontend1/core/error_helper.dart';" + content[insert_pos:]
        
    # Remplacer e.toString() par ErrorHelper.extractErrorMessage(e)
    # Remplacer _extractError(e) par ErrorHelper.extractErrorMessage(e)
    new_content = re.sub(r'e\.toString\(\)', 'ErrorHelper.extractErrorMessage(e)', content)
    new_content = re.sub(r'_extractError\(e\)', 'ErrorHelper.extractErrorMessage(e)', new_content)
    
    if new_content != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {filepath}")

def main():
    lib_dir = r"c:\Pharma_logiciels_version_01\frontend1\lib"
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if file.endswith('.dart'):
                process_file(os.path.join(root, file))

if __name__ == '__main__':
    main()
