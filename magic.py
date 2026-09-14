import os

print("UVM Magic Script Started! 🚀")

# 1. Sabhi text files ke andar uvm ko uvm se replace karna
for root, dirs, files in os.walk("."):
    for file in files:
        # Sirf code aur text files ko edit karenge (images ko nahi)
        if file.endswith(('.py', '.html', '.txt', '.json', '.sh', '.css', '.js')):
            filepath = os.path.join(root, file)
            try:
                with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                
                # Replace UVM -> UVM and uvm -> uvm
                new_content = content.replace('UVM', 'UVM').replace('uvm', 'uvm')
                
                if content != new_content:
                    with open(filepath, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f"[+] Text Updated in: {file}")
            except Exception as e:
                pass

# 2. Files ke naam badalna (jaise uvm.py -> uvm.py)
for root, dirs, files in os.walk(".", topdown=False):
    for name in files:
        if 'uvm' in name.lower():
            old_path = os.path.join(root, name)
            new_name = name.replace('uvm', 'uvm').replace('UVM', 'UVM')
            new_path = os.path.join(root, new_name)
            os.rename(old_path, new_path)
            print(f"[+] File Renamed: {name} -> {new_name}")

print("\nBoom! 💥 Sab kuch UVM ban gaya!")