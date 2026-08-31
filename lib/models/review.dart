class Review {
  final String userName;
  final double rating;
  final String timeAgo;
  final String text;
  final int likes;
  final int photoCount;

  const Review({
    required this.userName,
    required this.rating,
    required this.timeAgo,
    required this.text,
    this.likes = 0,
    this.photoCount = 0,
  });
}