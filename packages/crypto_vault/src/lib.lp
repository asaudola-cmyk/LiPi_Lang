@struct Token
  value: string
  expiry: i64
@end

@fn hash_password(pass)
  @! In real life, use proper hash
  return "hashed"
@end

@fn generate_token(user_id)
  return Token { value: "token", expiry: 9999 }
@end
