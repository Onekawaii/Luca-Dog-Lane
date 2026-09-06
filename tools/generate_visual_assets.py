#!/usr/bin/env python3
"""
Strawberry Omen Visual Asset Generator v0.3

Generates deterministic PNG image assets from visual_manifest.json placeholder prompts.
This is the first step in creating functional visual assets for the Strawberry Omen campaign.

Requirements:
- Python 3.11+
- Pillow (PIL) >= 10.0.0

Output Structure:
- campaigns/strawberry_omen/assets/generated/maps/          (1024x1024)
- campaigns/strawberry_omen/assets/generated/rooms/          (1024x768)  
- campaigns/strawberry_omen/assets/generated/textures/        (512x512)
- campaigns/strawberry_omen/assets/generated/items/          (512x512)
- campaigns/strawberry_omen/assets/generated/tokens/          (512x512)

Usage:
    python tools/generate_visual_assets.py

This will:
1. Load campaigns/strawberry_omen/visual_manifest.json
2. Generate deterministic PNGs from placeholder prompts
3. Save to assets/generated/ with proper categorization
4. Create campaigns/strawberry_omen/assets/generated/generated_manifest.json
5. Update visual_manifest.json references to generated assets

Note: This generates placeholder-style artistic representations
from the text prompts. For high-quality campaign materials, these
would typically be replaced by hand-drawn or commissioned art.
"""

import json
import os
import hashlib
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import random

# Seed for deterministic generation
random.seed(42)

class VisualAssetGenerator:
    def __init__(self, campaign_path: str = "campaigns/strawberry_omen"):
        self.campaign_path = Path(campaign_path)
        self.visual_manifest_path = self.campaign_path / "visual_manifest.json"
        self.generated_dir = self.campaign_path / "assets" / "generated"
        self.generated_manifest_path = self.campaign_path / "assets" / "generated_manifest.json"
        
        # Canvas sizes
        self.canvas_sizes = {
            "maps": (1024, 1024),
            "rooms": (1024, 768),
            "textures": (512, 512),
            "items": (512, 512),
            "tokens": (512, 512)
        }
        
        # Load visual manifest
        with open(self.visual_manifest_path, "r") as f:
            self.manifest = json.load(f)
            
    def create_text_texture(self, text: str, width: int, height: int, 
                          bg_color: tuple = (240, 240, 240),
                          fg_color: tuple = (50, 50, 50),
                          font_size: int = 20) -> Image.Image:
        """Create a text texture with word wrap."""
        image = Image.new("RGB", (width, height), bg_color)
        draw = ImageDraw.Draw(image)
        
        try:
            font = ImageFont.truetype("arial.ttf", font_size)
        except:
            font = ImageFont.load_default()
        
        # Simple text wrapping
        words = text.split()
        lines = []
        current_line = []
        current_length = 0
        
        for word in words:
            word_length = len(word) * font_size // 2
            if current_length + word_length <= width - 20 and len(current_line) < 10:
                current_line.append(word)
                current_length += word_length + 5
            else:
                if current_line:
                    lines.append(" ".join(current_line))
                current_line = [word]
                current_length = len(word) * font_size // 2
        
        if current_line:
            lines.append(" ".join(current_line))
        
        # Draw text
        y_offset = 10
        for line in lines:
            try:
                bbox = draw.textbbox((0, 0), line, font=font)
                text_width = bbox[2] - bbox[0]
                text_height = bbox[3] - bbox[1]
                x = (width - text_width) // 2
                draw.text((x, y_offset), line, fill=fg_color, font=font)
                y_offset += text_height + 5
            except:
                draw.text((10, y_offset), line, fill=fg_color)
                y_offset += font_size + 5
        
        return image
    
    def generate_color_from_text(self, text: str) -> tuple:
        """Generate a deterministic color from text."""
        hash_value = hashlib.md5(text.encode()).hexdigest()
        r = int(hash_value[0:2], 16)
        g = int(hash_value[2:4], 16)
        b = int(hash_value[4:6], 16)
        
        # Brighten up the colors
        r = min(255, r + 50)
        g = min(255, g + 50)
        b = min(255, b + 50)
        
        return (r, g, b)
    
    def create_pattern_background(self, width: int, height: int, pattern_type: str, color: tuple) -> Image.Image:
        """Create a pattern background."""
        image = Image.new("RGB", (width, height), color)
        draw = ImageDraw.Draw(image)
        
        if pattern_type == "grid":
            grid_size = 20
            for x in range(0, width, grid_size):
                draw.line([(x, 0), (x, height)], fill=(color[0]//2, color[1]//2, color[2]//2), width=1)
            for y in range(0, height, grid_size):
                draw.line([(0, y), (width, y)], fill=(color[0]//2, color[1]//2, color[2]//2), width=1)
        
        elif pattern_type == "diagonal":
            for x in range(-width, width * 2, 30):
                draw.line([(x, 0), (x - width, height)], fill=(color[0]//2, color[1]//2, color[2]//2), width=1)
        
        elif pattern_type == "dots":
            import math
            dot_radius = 2
            for x in range(dot_radius, width, 30):
                for y in range(dot_radius, height, 30):
                    draw.ellipse([(x - dot_radius, y - dot_radius), 
                                  (x + dot_radius, y + dot_radius)], fill=color)
        
        return image
    
    def generate_asset(self, asset_data: dict, category: str) -> Image.Image:
        """Generate an image from asset data."""
        width, height = self.canvas_sizes[category]
        asset_id = asset_data["asset_id"]
        filename = asset_data["filename"]
        
        # Create base image with deterministic color based on asset_id
        base_color = self.generate_color_from_text(asset_id)
        
        # Determine pattern type from asset_id for variety
        pattern_types = ["grid", "diagonal", "dots"]
        pattern_type = pattern_types[int(hashlib.md5(asset_id.encode()).hexdigest()[0], 16) % len(pattern_types)]
        
        # Create background
        image = self.create_pattern_background(width, height, pattern_type, base_color)
        
        # Create overlay with text
        draw = ImageDraw.Draw(image)
        
        # Add asset ID text
        try:
            title_font = ImageFont.truetype("arial.ttf", 24)
            desc_font = ImageFont.truetype("arial.ttf", 16)
            small_font = ImageFont.truetype("arial.ttf", 12)
        except:
            title_font = ImageFont.load_default()
            desc_font = ImageFont.load_default()
            small_font = ImageFont.load_default()
        
        # Draw asset ID
        draw.text((10, 10), f"ID: {asset_id}", fill=(255, 255, 255), font=title_font)
        
        # Draw filename if available
        if filename != f"{asset_id}.placeholder.md":
            draw.text((10, 40), f"File: {filename}", fill=(255, 255, 255), font=desc_font)
        
        # Draw type
        asset_type = asset_data.get("type", "placeholder")
        draw.text((10, 60), f"Type: {asset_type}", fill=(255, 255, 255), font=desc_font)
        
        # Draw status
        status = asset_data.get("status", "unknown")
        draw.text((10, 80), f"Status: {status}", fill=(255, 255, 255), font=small_font)
        
        # Add category-specific decorations
        if category == "maps":
            # Draw a simple map-like grid
            map_color = (100, 100, 150)
            draw.rectangle([(50, 50), (width - 50, height - 50)], outline=map_color, width=2)
            draw.ellipse([(width // 2 - 30, height // 2 - 30), 
                         (width // 2 + 30, height // 2 + 30)], outline=map_color, width=2)
        
        elif category == "textures":
            # Create a texture pattern
            texture_color = (base_color[0]//2, base_color[1]//2, base_color[2]//2)
            for y in range(0, height, 10):
                draw.line([(0, y), (width, y)], fill=texture_color, width=1)
        
        elif category == "items":
            # Draw a simple icon
            icon_color = (150, 150, 100)
            center_x, center_y = width // 2, height // 2
            draw.ellipse([(center_x - 40, center_y - 40), 
                         (center_x + 40, center_y + 40)], 
                        fill=icon_color, outline=(255, 255, 255), width=2)
        
        elif category == "tokens":
            # Draw a character/token icon
            token_color = (150, 100, 150)
            draw.ellipse([(20, 20), (100, 100)], fill=token_color, outline=(255, 255, 255), width=2)
            draw.ellipse([(width - 120, 20), (width - 20, 100)], fill=token_color, outline=(255, 255, 255), width=2)
        
        elif category == "rooms":
            # Draw room-like layout
            room_color = (100, 150, 100)
            # Draw room area
            draw.rectangle([(80, 80), (width - 80, height - 80)], fill=room_color, outline=(255, 255, 255), width=2)
        
        return image
    
    def generate_all_assets(self):
        """Generate all visual assets from manifest."""
        print("Generating visual assets from manifest...")
        
        # Create output directories
        for category in self.canvas_sizes.keys():
            (self.generated_dir / category).mkdir(parents=True, exist_ok=True)
        
        # Track generated assets
        generated_manifest = {
            "generated_by": "visual_asset_generator_v0.3",
            "generation_date": "2026-06-13",
            "version": "0.3.0",
            "generated_assets": []
        }
        
        # Generate assets for each category
        for category in self.canvas_sizes.keys():
            print(f"\nGenerating {category}...")
            assets = self.manifest["assets"].get(category, [])
            
            for asset_data in assets:
                print(f"  - Generating: {asset_data['asset_id']}")
                
                # Generate image
                image = self.generate_asset(asset_data, category)
                
                # Save image
                filename = f"{asset_data['asset_id']}.png"
                output_path = self.generated_dir / category / filename
                image.save(output_path, "PNG")
                
                # Add to manifest
                generated_manifest["generated_assets"].append({
                    "category": category,
                    "asset_id": asset_data["asset_id"],
                    "filename": filename,
                    "path": f"assets/generated/{category}/{filename}",
                    "source_file": asset_data["filename"],
                    "source_path": asset_data["path"]
                })
        
        # Save generated manifest
        with open(self.generated_manifest_path, "w") as f:
            json.dump(generated_manifest, f, indent=2)
        
        print(f"\nGenerated {len(generated_manifest['generated_assets'])} assets")
        print(f"Output directory: {self.generated_dir}")
        print(f"Manifest saved to: {self.generated_manifest_path}")
        
    def update_visual_manifest(self):
        """Update visual_manifest.json to reference generated assets."""
        print("\nUpdating visual_manifest.json to reference generated assets...")
        
        # For now, we'll keep the original placeholder files and add references
        # In a real implementation, you might want to remove the placeholder references
        # and add generated asset references
        
        # Update dependencies required_files to include generated assets
        if "dependencies" not in self.manifest:
            self.manifest["dependencies"] = {}
        
        if "required_files" not in self.manifest["dependencies"]:
            self.manifest["dependencies"]["required_files"] = []
        
        # Add generated assets to required files
        for asset in self.manifest["assets"].values():
            for category in self.canvas_sizes.keys():
                for gen_asset in self.manifest["assets"][category]:
                    if gen_asset["status"] != "placeholder":
                        generated_path = f"assets/generated/{category}/{gen_asset['asset_id']}.png"
                        if generated_path not in self.manifest["dependencies"]["required_files"]:
                            self.manifest["dependencies"]["required_files"].append(generated_path)
        
        # Save updated manifest
        with open(self.visual_manifest_path, "w") as f:
            json.dump(self.manifest, f, indent=2)
        
        print("Updated visual_manifest.json")


def main():
    print("=== Strawberry Omen Visual Asset Generator v0.3 ===")
    print("Generating deterministic PNG assets from placeholder prompts")
    print()
    
    try:
        generator = VisualAssetGenerator()
        generator.generate_all_assets()
        generator.update_visual_manifest()
        
        print("\nVisual asset generation complete!")
        print(f"Generated assets are available in: {generator.generated_dir}")
        print(f"Generated manifest: {generator.generated_manifest_path}")
        
    except Exception as e:
        print(f"Error generating visual assets: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    return 0


if __name__ == "__main__":
    exit(main())