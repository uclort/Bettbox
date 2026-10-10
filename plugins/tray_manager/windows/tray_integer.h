#pragma once

#include <cstdint>
#include <optional>
#include <variant>

namespace tray_manager {

// StandardMethodCodec 会按数值大小选择 32 位或 64 位整数。
template <typename Value>
std::optional<int64_t> ReadInteger(const Value* value) {
  if (value == nullptr) return std::nullopt;
  if (const auto* number = std::get_if<int32_t>(value)) return *number;
  if (const auto* number = std::get_if<int64_t>(value)) return *number;
  return std::nullopt;
}

}  // namespace tray_manager
