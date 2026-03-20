
f = open(r'c:\Users\User\StudioProjects\FYP\lib\User\selfHelp.dart', 'rb')
data = f.read()
f.close()

# Meditation filter fix
old_med = b"                                       return matchesSearch && matchesDuration;\n"
new_med = b"""                                       bool matchesCategory = true;
                                       if (_selectedMeditationCategory == 'Favourite') {
                                         matchesCategory = _favoritedResources.contains(doc.id);
                                       }
                                       
                                       return matchesSearch && matchesDuration && matchesCategory;\n"""

# Article filter fix  
old_art = b"                               return (title.contains(_searchQuery) || tag.contains(_searchQuery)) && matchesDuration;\n"
new_art = b"""                               bool matchesArticleCategory = true;
                               if (_selectedArticleCategory == 'Favourite') {
                                 matchesArticleCategory = _favoritedResources.contains(doc.id);
                               }
                               
                               return (title.contains(_searchQuery) || tag.contains(_searchQuery)) && matchesDuration && matchesArticleCategory;\n"""

# Try exact 39-space version for meditation
old_med2 = b"                                       return matchesSearch && matchesDuration;\n"

# The hex showed 39 spaces then "return matchesSearch && matchesDuration;\n"
old_exact = b" " * 39 + b"return matchesSearch && matchesDuration;\n"

if old_exact in data:
    indent = b" " * 39
    new_exact = (
        indent + b"bool matchesCategory = true;\n" +
        indent + b"if (_selectedMeditationCategory == 'Favourite') {\n" +
        indent + b"  matchesCategory = _favoritedResources.contains(doc.id);\n" +
        indent + b"}\n" +
        indent + b"\n" +
        indent + b"return matchesSearch && matchesDuration && matchesCategory;\n"
    )
    data = data.replace(old_exact, new_exact, 1)
    print("Meditation filter FIXED")
else:
    print("Meditation filter NOT FOUND with 39 spaces")

# Find article return line
target_art = b"return (title.contains(_searchQuery) || tag.contains(_searchQuery)) && matchesDuration;\n"
art_idx = data.find(target_art)
if art_idx >= 0:
    # count spaces before it
    start = art_idx - 1
    spaces = 0
    while start >= 0 and data[start:start+1] == b' ':
        spaces += 1
        start -= 1
    print(f"Article return found with {spaces} leading spaces")
    indent = b" " * spaces
    old_exact_art = indent + target_art
    new_exact_art = (
        indent + b"bool matchesArticleCategory = true;\n" +
        indent + b"if (_selectedArticleCategory == 'Favourite') {\n" +
        indent + b"  matchesArticleCategory = _favoritedResources.contains(doc.id);\n" +
        indent + b"}\n" +
        indent + b"\n" +
        indent + b"return (title.contains(_searchQuery) || tag.contains(_searchQuery)) && matchesDuration && matchesArticleCategory;\n"
    )
    data = data.replace(old_exact_art, new_exact_art, 1)
    print("Article filter FIXED")
else:
    print("Article return NOT FOUND")

f = open(r'c:\Users\User\StudioProjects\FYP\lib\User\selfHelp.dart', 'wb')
f.write(data)
f.close()
print("File saved.")
