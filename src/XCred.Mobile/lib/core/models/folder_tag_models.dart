// Mirrors XCred.Core.DTOs.Folders.FolderDto / Credentials.TagDto — picker-only models
// for Sprint 1.4's credential form (no CRUD, no offline cache; real Folder/Tag
// management screens with their own repositories/caching are Sprint 1.5 scope).
class FolderNode {
  final String id;
  final String name;
  final String? parentFolderId;
  final List<FolderNode> children;

  const FolderNode({
    required this.id,
    required this.name,
    this.parentFolderId,
    required this.children,
  });

  factory FolderNode.fromJson(Map<String, dynamic> json) => FolderNode(
        id: json['id'] as String,
        name: json['name'] as String,
        parentFolderId: json['parentFolderId'] as String?,
        children: ((json['children'] as List<dynamic>?) ?? [])
            .map((c) => FolderNode.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

class FlatFolder {
  final String id;
  final String indentedName;
  const FlatFolder({required this.id, required this.indentedName});
}

/// Flattens the folder tree into an indented pick-list, matching the web app's
/// `flattenFolders` (e.g. "Parent / Child").
List<FlatFolder> flattenFolders(List<FolderNode> nodes, [String prefix = '']) {
  final result = <FlatFolder>[];
  for (final f in nodes) {
    result.add(FlatFolder(id: f.id, indentedName: '$prefix${f.name}'));
    if (f.children.isNotEmpty) {
      result.addAll(flattenFolders(f.children, '$prefix${f.name} / '));
    }
  }
  return result;
}

class TagSummary {
  final String id;
  final String name;
  final String color;
  const TagSummary({required this.id, required this.name, required this.color});

  factory TagSummary.fromJson(Map<String, dynamic> json) => TagSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        color: json['color'] as String,
      );
}
