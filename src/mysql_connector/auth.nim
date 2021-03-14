import std/sha1, sequtils
import nimSHA2

import packet, utility

func auth_mysql_native_password*(password, nonce: string): Packet =
  func to_string(securehash: SecureHash): string =
    return Sha1Digest(securehash).map(func(x: uint8): char = chr(x)).to_string()

  let hashed_password = secureHash(password)
  let digest1 = secureHash(hashed_password.to_string())
  let digest2 = secureHash(nonce & digest1.to_string())

  result.setLen(Sha1Digest(hashed_password).len)
  for i, _ in Sha1Digest(hashed_password):
    result[i] = byte(Sha1Digest(hashed_password)[i]) xor
                byte(Sha1Digest(digest2)[i])

  return result

func auth_caching_sha2_password*(password, nonce: string): Packet =
  var sha2 = initSHA[SHA256]()
  sha2.update(password)
  let hashed_password = sha2.final()

  sha2 = initSHA[SHA256]()
  sha2.update(hashed_password.toString())
  let digest1 = sha2.final()

  sha2 = initSHA[SHA256]()
  sha2.update(digest1.toString())
  sha2.update(nonce)
  let digest2 = sha2.final()

  result.setLen(hashed_password.len)
  for i, _ in hashed_password:
    result[i] = byte(hashed_password[i]) xor byte(digest2[i])

  return result