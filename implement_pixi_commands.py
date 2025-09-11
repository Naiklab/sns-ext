#!/usr/bin/env python3
"""
Script to implement actual Pixi commands in the migrated files
"""

import os
import re

def implement_pixi_in_file(file_path):
    """Replace comment placeholders with actual Pixi commands"""
    print(f"Implementing Pixi commands in: {file_path}")
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    original_content = content
    
    # Pattern to find our comment blocks and implement them
    patterns = [
        # Pattern for simple environment activation
        (r'# Pixi environment: (\w+)\n# Use: pixi run -e \1 <command>', 
         lambda m: f'# Activate Pixi environment: {m.group(1)}\n# Commands in this section will use pixi run -e {m.group(1)}'),
        
        # Pattern for error handling case
        (r'# Pixi environment: (\w+)\n# Use: pixi run -e \1 <command> \|\| \{ echo "Failed to activate \1 pixi environment"; exit 1; \}',
         lambda m: f'# Pixi environment: {m.group(1)}\n# Error handling for pixi environment activation')
    ]
    
    for pattern, replacement in patterns:
        content = re.sub(pattern, replacement, content)
    
    # Now let's add specific implementations for each file type
    if 'sambamba' in content and 'pixi run -e atac' not in content:
        # Add pixi wrapper function for sambamba commands
        sambamba_pattern = r'(sambamba\s+[^\n]+)'
        content = re.sub(sambamba_pattern, r'pixi run -e atac \1', content)
    
    if 'deeptools' in file_path and 'pixi run -e deeptools' not in content:
        # Add pixi wrapper for deeptools commands
        deeptools_patterns = [
            r'(bamCoverage[^\n]+)',
            r'(plotProfile[^\n]+)',
            r'(plotHeatmap[^\n]+)',
            r'(computeMatrix[^\n]+)'
        ]
        for pattern in deeptools_patterns:
            content = re.sub(pattern, r'pixi run -e deeptools \1', content)
    
    if 'dos2unix' in content and 'pixi run -e rna' not in content:
        # Add pixi wrapper for dos2unix
        dos2unix_pattern = r'(dos2unix[^\n]+)'
        content = re.sub(dos2unix_pattern, r'pixi run -e rna \1', content)
    
    if 'macs3' in content and 'pixi run -e macs3' not in content:
        # Add pixi wrapper for macs3 commands
        macs3_pattern = r'(macs3\s+[^\n]+)'
        content = re.sub(macs3_pattern, r'pixi run -e macs3 \1', content)
    
    if content != original_content:
        with open(file_path, 'w') as f:
            f.write(content)
        print(f"  ✓ Implemented Pixi commands in {file_path}")
        return True
    else:
        print(f"  - No additional changes needed in {file_path}")
        return False

def main():
    """Main implementation function"""
    print("🔧 Implementing Pixi commands in migrated files...")
    
    # Files that were updated by the migration script
    updated_files = [
        'scripts/fix-csv.sh',
        'segments/peaks-macs3-hmmratac.sh',
        'segments/qc-fastqscreen.sh',
        'segments/bigwig-deeptools.sh',
        'segments/peaks-macs2.sh',
        'segments/bam-dedup-sambamba.sh',
        'segments/align-bowtie2-atac.sh'
    ]
    
    implemented_files = []
    
    for file_path in updated_files:
        if os.path.exists(file_path):
            if implement_pixi_in_file(file_path):
                implemented_files.append(file_path)
        else:
            print(f"  ⚠️  File not found: {file_path}")
    
    print(f"\n✅ Implementation completed!")
    print(f"📝 Modified {len(implemented_files)} files:")
    for file_path in implemented_files:
        print(f"   - {file_path}")
    
    print(f"\n📋 Remember to:")
    print(f"   1. Test the modified scripts")
    print(f"   2. Verify pixi environments work correctly")
    print(f"   3. Update any remaining manual command executions")

if __name__ == "__main__":
    main()
