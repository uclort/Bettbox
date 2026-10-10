#include "../tray_integer.h"

#include <cassert>
#include <limits>
#include <string>

int main() {
  using Value = std::variant<std::monostate, bool, int32_t, int64_t, double,
                             std::string>;
  for (const int32_t number : {0, 1234, 5678, 2147483647}) {
    const Value value(number);
    assert(tray_manager::ReadInteger(&value) == number);
  }
  const Value large(int64_t{2147483648LL});
  assert(tray_manager::ReadInteger(&large) == 2147483648LL);
  const Value max(std::numeric_limits<int64_t>::max());
  assert(tray_manager::ReadInteger(&max) == std::numeric_limits<int64_t>::max());
  const Value negative(int32_t{-1});
  assert(tray_manager::ReadInteger(&negative) == -1);
  const Value boolean(false);
  const Value decimal(1.0);
  assert(!tray_manager::ReadInteger(&boolean));
  assert(!tray_manager::ReadInteger(&decimal));
  assert(!tray_manager::ReadInteger<Value>(nullptr));
}
