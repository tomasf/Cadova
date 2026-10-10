// Stands in for ICU's 34 MB data package. ICU finds no data at run time, so anything that needs it
// (date and number formatting for a locale, collation and the like) fails.
const unsigned char icudt76_dat[16] = {0};
