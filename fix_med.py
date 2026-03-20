
f = open(r'c:\Users\User\StudioProjects\FYP\lib\User\selfHelp.dart', 'rb')
data = f.read()
f.close()

# Meditation: 30 spaces
indent = b' ' * 30
old_exact = indent + b'return matchesSearch && matchesDuration;\n'
new_exact = (
    indent + b"bool matchesCategory = true;\n" +
    indent + b"if (_selectedMeditationCategory == 'Favourite') {\n" +
    indent + b"  matchesCategory = _favoritedResources.contains(doc.id);\n" +
    indent + b"}\n" +
    indent + b"\n" +
    indent + b"return matchesSearch && matchesDuration && matchesCategory;\n"
)
if old_exact in data:
    data = data.replace(old_exact, new_exact, 1)
    print("Meditation FIXED")
else:
    print("Meditation NOT FOUND")

f = open(r'c:\Users\User\StudioProjects\FYP\lib\User\selfHelp.dart', 'wb')
f.write(data)
f.close()
print("Done")
