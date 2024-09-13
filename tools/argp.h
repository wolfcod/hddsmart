#ifndef __ARGP_H
#define __ARGP_H

#define OPTION_ARG_OPTIONAL 1
#define OPTION_ARG_SWITCH	2
#define OPTION_IS_SET		4

struct argp_option
{
	const char* name;
	int key;
	const char* arg;
	int flags;
	const char* doc;
	int group;
	char* value;
};

#endif
