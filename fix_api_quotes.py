import os

directory = '/home/rchennau/ai_colab/webui/api/'
files = [
    'config.py', 'conductor.py', 'kb.py', 'terminal.py', 
    'system.py', 'federation.py', 'models.py', 'vision.py', 'inference.py'
]

for filename in files:
    filepath = os.path.join(directory, filename)
    if not os.path.exists(filepath):
        print(f"Skipping {filename}: Not found")
        continue
    
    with open(filepath, 'r') as f:
        lines = f.readlines()
    
    new_lines = []
    fixed = False
    for line in lines:
        # First, remove any trailing ' that my previous sed might have added to config.py
        if filename == 'config.py' and line.endswith("'\n"):
            line = line[:-2] + "\n"
            fixed = True
        elif filename == 'config.py' and line.endswith("'"):
            line = line[:-1]
            fixed = True
            
        if '\\"' in line or "\\'" in line:
            line = line.replace('\\"', '"').replace("\\'", "'")
            fixed = True
        new_lines.append(line)
    
    if fixed:
        with open(filepath, 'w') as f:
            f.writelines(new_lines)
        print(f"Fixed {filename}")
    else:
        print(f"No changes needed for {filename}")
