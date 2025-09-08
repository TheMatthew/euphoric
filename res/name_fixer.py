#!/usr/bin/env python3
"""
NPC Name Extractor Script
Extracts clean names from the NAME field in npcs.json and adds them as separate CLEAN_NAME fields.
"""

import json
import re
import sys
import os

def extract_clean_name(name_text):
    """
    Extract a clean name from various formats like:
    "I am Alric, a humble farmer." -> "Alric"
    "My name's Marta." -> "Marta"
    "Call me Rusk." -> "Rusk"
    "They call me Mira." -> "Mira"
    "I am a guard." -> "Guard"
    """
    if not name_text:
        return "Unknown"
    
    # Remove leading/trailing whitespace
    name_text = name_text.strip()
    
    # Patterns to extract names
    patterns = [
        # "I am [Name]" patterns
        r"I am ([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)",  # "I am Alric" or "I am Brother Jorin"
        r"I am (Sir|Dame|Brother|Sister|Captain|King|Queen|Prince|Princess|Elder|Scholar|Lady|Lord|Chancellor|Cook|Guard|Page|Fisher)\s+([A-Z][a-z]+)",  # "I am Sir Halric"
        r"I am (a|an)\s+([A-Z][a-z]+)",  # "I am a guard" -> "Guard"
        
        # "My name's [Name]" patterns  
        r"My name'?s\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)",  # "My name's Marta"
        r"My name is\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)",   # "My name is Marta"
        
        # "Call me [Name]" patterns
        r"Call me\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)",      # "Call me Rusk"
        
        # "They call me [Name]" patterns
        r"They call me\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)", # "They call me Mira"
        
        # Direct name patterns (fallback)
        r"^([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)$",              # Just "Alric" or "Brother Jorin"
    ]
    
    # Try each pattern
    for pattern in patterns:
        match = re.search(pattern, name_text)
        if match:
            # For title + name patterns (like "Sir Halric")
            if len(match.groups()) > 1:
                title = match.group(1)
                name = match.group(2)
                
                # If title is "a" or "an", capitalize the following word
                if title.lower() in ["a", "an"]:
                    return name.title()
                else:
                    return f"{title} {name}"
            else:
                return match.group(1)
    
    # If no pattern matches, try to extract any capitalized word
    words = name_text.split()
    for word in words:
        # Look for capitalized words that aren't common articles/pronouns
        if (word[0].isupper() and 
            word.lower() not in ["i", "am", "my", "name", "names", "call", "me", "they", "a", "an", "the"]):
            return word.rstrip(".,!?")
    
    # Last resort: return "Unknown"
    return "Unknown"

def process_npc_data(data):
    """Process the NPC data and add CLEAN_NAME fields."""
    processed_count = 0
    
    for location, npcs in data.items():
        print(f"\nProcessing {location}:")
        for i, npc in enumerate(npcs):
            original_name = npc.get("NAME", "")
            clean_name = extract_clean_name(original_name)
            
            # Add the clean name field
            npc["CLEAN_NAME"] = clean_name
            
            print(f"  {i+1:2d}. '{original_name}' -> '{clean_name}'")
            processed_count += 1
    
    return processed_count

def main():
    # Default file path
    input_file = "npcs.json"
    output_file = "npcs_with_clean_names.json"
    
    # Check for command line arguments
    if len(sys.argv) > 1:
        input_file = sys.argv[1]
    if len(sys.argv) > 2:
        output_file = sys.argv[2]
    
    # Check if input file exists
    if not os.path.exists(input_file):
        print(f"Error: Input file '{input_file}' not found!")
        print(f"Usage: python {sys.argv[0]} [input_file] [output_file]")
        print(f"Example: python {sys.argv[0]} npcs.json npcs_updated.json")
        return 1
    
    try:
        # Read the JSON file
        print(f"Reading from: {input_file}")
        with open(input_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # Process the data
        processed_count = process_npc_data(data)
        
        # Write the updated JSON file
        print(f"\nWriting to: {output_file}")
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        
        print(f"\nSuccess! Processed {processed_count} NPCs.")
        print(f"Updated file saved as: {output_file}")
        
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in {input_file}")
        print(f"JSON Error: {e}")
        return 1
    except Exception as e:
        print(f"Error: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)
