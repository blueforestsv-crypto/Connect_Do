class ContactModel {
  final String id;
  final String name;
  final String email;
  final String career;
  final String photo;
  final String status;

  ContactModel({
    required this.id,
    required this.name,
    required this.email,
    required this.career,
    required this.photo,
    required this.status,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Usuario',
      email: json['email'] ?? '',
      career: json['career'] ?? 'Sin carrera',
      photo: json['photo'] ?? '',
      status: json['status'] ?? 'none',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'career': career,
      'photo': photo,
      'status': status,
    };
  }

  ContactModel copyWith({
    String? id,
    String? name,
    String? email,
    String? career,
    String? photo,
    String? status,
  }) {
    return ContactModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      career: career ?? this.career,
      photo: photo ?? this.photo,
      status: status ?? this.status,
    );
  }
}
