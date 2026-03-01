#include <stdlib.h>
#include <dbus/dbus.h>

DBusError *jg_dbus_error_new(void) {
  DBusError *e = (DBusError *)calloc(1, sizeof(DBusError));

  if (!e) return NULL;

  dbus_error_init(e);

  return e;
}

void jg_dbus_error_free(DBusError *e) {
  if (!e) return;

  dbus_error_free(e);

  free(e);
}

const char *jg_dbus_error_message(DBusError *e) {
  if (!e) return NULL;
  if (!dbus_error_is_set(e)) return NULL;

  return e->message;
}

int jg_dbus_error_is_set(DBusError *e) {
  if (!e) return 0;
  return dbus_error_is_set(e);
}
