#!/usr/bin/env ruby

# frozen_string_literal: true

require "fileutils"
require "pathname"
require "set"

HOME = Dir.home
VAULT = Pathname.new(File.join(HOME, "Vault"))
SRC_NOTES = VAULT.join("Languages")
SRC_ATTACH = VAULT.join("Attachments")

DEST_ROOT = Pathname.new(Dir.pwd)
DEST_NOTES = DEST_ROOT.join("notes")
DEST_ASSETS = DEST_ROOT.join("note-assets")

# Add more extensions if you use them
ATTACH_EXT = /\.(png|jpe?g|gif|svg|webp|pdf|mp3|m4a|wav)$/i

def rm_rf(path)
  FileUtils.rm_rf(path.to_s)
end

def mkdir_p(path)
  FileUtils.mkdir_p(path.to_s)
end

def copy_file(src, dest)
  mkdir_p(dest.dirname)
  FileUtils.cp(src.to_s, dest.to_s)
end

def read_utf8(path)
  File.read(path.to_s, mode: "r:BOM|UTF-8")
end

def write_utf8(path, content)
  mkdir_p(path.dirname)
  File.write(path.to_s, content, mode: "w:UTF-8")
end

def asset_name_from_target(target)
  # For Obsidian: "file.png", "file.png|300", "Note#Heading", etc.
  base = target.split("|", 2).first
  File.basename(base)
end

def find_assets_in_markdown(content)
  assets = Set.new

  # Obsidian embed: ![[Pasted image 2025...png]] or ![[foo.png|300]]
  content.scan(/!\[\[([^\]]+)\]\]/) do |m|
    file = asset_name_from_target(m[0])
    assets << file if file.match?(ATTACH_EXT)
  end

  # Markdown links / images: ![](path/file.png) or [](path/file.pdf)
  content.scan(/\]\(([^)]+)\)/) do |m|
    target = m[0]
    file = File.basename(target)
    assets << file if file.match?(ATTACH_EXT)
  end

  assets
end

def rewrite_links_for_export(content)
  # Rewrite Obsidian embeds of attachments to standard Markdown that works anywhere:
  # ![[image.png]] => ![](assets/image.png)
  content = content.gsub(/!\[\[([^\]]+)\]\]/) do |match|
    target = Regexp.last_match(1)
    file = asset_name_from_target(target)
    if file.match?(ATTACH_EXT)
      "![](assets/#{file})"
    else
      match
    end
  end

  # Rewrite markdown links/images to assets/<file> when they point at an attachment.
  content.gsub(/\]\(([^)]+)\)/) do |match|
    target = Regexp.last_match(1)
    file = File.basename(target)
    if file.match?(ATTACH_EXT)
      "](assets/#{file})"
    else
      match
    end
  end
end

unless SRC_NOTES.directory?
  abort "Source notes folder not found: #{SRC_NOTES}"
end

unless SRC_ATTACH.directory?
  warn "Warning: Attachments folder not found: #{SRC_ATTACH} (will still export notes)"
end

# Clean destination
rm_rf(DEST_NOTES)
rm_rf(DEST_ASSETS)
mkdir_p(DEST_NOTES)
mkdir_p(DEST_ASSETS)

note_paths = Dir.glob(SRC_NOTES.join("**/*.md").to_s)
used_assets = Set.new
exported = 0

note_paths.each do |src|
  src_path = Pathname.new(src)
  rel = src_path.relative_path_from(SRC_NOTES)
  dest_path = DEST_NOTES.join(rel)

  content = read_utf8(src_path)
  used_assets.merge(find_assets_in_markdown(content))
  content = rewrite_links_for_export(content)

  write_utf8(dest_path, content)
  exported += 1
end

# Copy assets
copied_assets = 0
missing_assets = []

used_assets.each do |file|
  next unless SRC_ATTACH.directory?

  src = SRC_ATTACH.join(file)
  dest = DEST_ASSETS.join(file)

  if src.exist?
    copy_file(src, dest)
    copied_assets += 1
  else
    missing_assets << file
  end
end

puts "Exported #{exported} notes"
puts "Copied #{copied_assets} assets (referenced: #{used_assets.size})"
if missing_assets.any?
  warn "Missing attachments (not found in #{SRC_ATTACH}):"
  missing_assets.sort.each { |f| warn "  - #{f}" }
end
