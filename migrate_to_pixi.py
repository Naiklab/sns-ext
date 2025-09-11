#!/usr/bin/env python3
"""
Migration script to replace conda environments with Pixi environments in SNS-EXT
"""

import os
import re
import glob

# Mapping of conda environments to Pixi environments
ENV_MAPPING = {
    '/sc/arion/projects/naiklab/ikjot/conda_envs/atac-star': 'atac',
    '/sc/arion/projects/naiklab/ikjot/conda_envs/deeptools': 'deeptools', 
    '/sc/arion/projects/naiklab/ikjot/conda_envs/rna-star': 'rna',
    'rna-star': 'rna',  # for the qc-fastqscreen.sh case
}

def update_conda_activation(file_path):
    """Update conda activation commands to pixi run commands"""
    print(f"Processing: {file_path}")
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    original_content = content
    
    # Pattern 1: conda activate /path/to/env
    pattern1 = r'conda activate (/sc/arion/projects/naiklab/ikjot/conda_envs/[\w-]+)'
    def replace1(match):
        conda_path = match.group(1)
        if conda_path in ENV_MAPPING:
            pixi_env = ENV_MAPPING[conda_path]
            return f'# Pixi environment: {pixi_env}\n# Use: pixi run -e {pixi_env} <command>'
        return match.group(0)
    
    content = re.sub(pattern1, replace1, content)
    
    # Pattern 2: source activate /path/to/env
    pattern2 = r'source activate (/sc/arion/projects/naiklab/ikjot/conda_envs/[\w-]+)'
    def replace2(match):
        conda_path = match.group(1)
        if conda_path in ENV_MAPPING:
            pixi_env = ENV_MAPPING[conda_path]
            return f'# Pixi environment: {pixi_env}\n# Use: pixi run -e {pixi_env} <command>'
        return match.group(0)
    
    content = re.sub(pattern2, replace2, content)
    
    # Pattern 3: conda activate env-name (without full path)
    pattern3 = r'conda activate (rna-star) \|\| \{ echo "Failed to activate RNA-star conda environment"; exit 1; \}'
    def replace3(match):
        env_name = match.group(1)
        if env_name in ENV_MAPPING:
            pixi_env = ENV_MAPPING[env_name]
            return f'# Pixi environment: {pixi_env}\n# Use: pixi run -e {pixi_env} <command> || {{ echo "Failed to activate {pixi_env} pixi environment"; exit 1; }}'
        return match.group(0)
    
    content = re.sub(pattern3, replace3, content)
    
    # Handle $MACS3_ENV variable case
    if '$MACS3_ENV' in content:
        content = content.replace('source activate $MACS3_ENV # Contains sambamba', 
                                  '# Pixi environment: macs3\n# Use: pixi run -e macs3 <command>')
    
    if content != original_content:
        with open(file_path, 'w') as f:
            f.write(content)
        print(f"  ✓ Updated {file_path}")
        return True
    else:
        print(f"  - No changes needed in {file_path}")
        return False

def main():
    """Main migration function"""
    print("🚀 Starting SNS-EXT migration from Conda to Pixi...")
    
    # Find all shell script files that might contain conda commands
    script_patterns = [
        'scripts/*.sh',
        'segments/*.sh', 
        'routes/*.sh'
    ]
    
    updated_files = []
    
    for pattern in script_patterns:
        for file_path in glob.glob(pattern):
            if update_conda_activation(file_path):
                updated_files.append(file_path)
    
    print(f"\n✅ Migration completed!")
    print(f"📝 Updated {len(updated_files)} files:")
    for file_path in updated_files:
        print(f"   - {file_path}")
    
    print(f"\n📋 Next steps:")
    print(f"   1. Install Pixi: curl -fsSL https://pixi.sh/install.sh | bash")
    print(f"   2. Initialize environments: pixi install")
    print(f"   3. Test environments: pixi run -e atac sambamba --version")
    print(f"   4. Update scripts to use 'pixi run -e <env> <command>' pattern")

if __name__ == "__main__":
    main()
