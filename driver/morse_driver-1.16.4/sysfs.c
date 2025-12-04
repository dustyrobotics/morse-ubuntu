/*
 * Copyright 2024 Morse Micro
 *
 */

#include <linux/sysfs.h>
#include <linux/gpio.h>
#include "morse.h"
#include "sysfs.h"
#include "debug.h"

static ssize_t board_type_show(struct device *dev,
					   struct device_attribute *attr,
					   char *buf)
{
	struct morse *mors = dev_get_drvdata(dev);

	if (!mors)
		return -EINVAL;

	if (mors->board_id < 0)
		return mors->board_id;

#if KERNEL_VERSION(5, 10, 0) <= LINUX_VERSION_CODE
	return sysfs_emit(buf, "%d\n", mors->board_id);
#else
	return snprintf(buf, PAGE_SIZE, "%d\n", mors->board_id);
#endif
}

static DEVICE_ATTR_RO(board_type);

static ssize_t countries_show(struct device *dev,
			      struct device_attribute *attr,
			      char *buf)
{
	struct morse *mors = dev_get_drvdata(dev);
	int i, len = 0;

	if (!mors || !mors->regdoms || mors->num_regdoms <= 0)
		return -EINVAL;

	for (i = 0; i < mors->num_regdoms; i++) {
#if KERNEL_VERSION(5, 10, 0) <= LINUX_VERSION_CODE
		len += sysfs_emit_at(buf, len, "%s ", mors->regdoms[i]);
#else
		len += snprintf(buf + len, PAGE_SIZE - len, "%s ", mors->regdoms[i]);
		if (len >= PAGE_SIZE)
			break;
#endif
	}

	if (len > 0 && buf[len - 1] == ' ')
		buf[len - 1] = '\n';

	return len;
}

static DEVICE_ATTR_RO(countries);

static ssize_t mm_4v3_fem_show(struct device *dev,
					   struct device_attribute *attr,
					   char *buf)
{
	struct morse *mors = dev_get_drvdata(dev);

	if (!mors || !mors->cfg)
		return -EINVAL;

#if KERNEL_VERSION(5, 10, 0) <= LINUX_VERSION_CODE
	return sysfs_emit(buf, "%d\n", morse_get_4v3_fem_state(mors));
#else
	return snprintf(buf, PAGE_SIZE, "%d\n", morse_get_4v3_fem_state(mors));
#endif
}

static DEVICE_ATTR_RO(mm_4v3_fem);

int morse_sysfs_init(struct morse *mors)
{
	int ret;

	ret = device_create_file(mors->dev, &dev_attr_board_type);
	if (ret < 0)
		MORSE_ERR(mors, "failed to create sysfs file board_type");

	ret = device_create_file(mors->dev, &dev_attr_countries);
	if (ret < 0)
		MORSE_ERR(mors, "failed to create sysfs file countries");

	// Create a sysfs entry only when 4.3V FEM Support configure from dts.
	if (gpio_is_valid(mors->cfg->mm_4v3_fem_gpio)) {
		ret = device_create_file(mors->dev, &dev_attr_mm_4v3_fem);
		if (ret < 0)
			MORSE_ERR(mors, "failed to create sysfs file 4,3v FEM support");
	}
	return ret;
}

void morse_sysfs_free(struct morse *mors)
{
	device_remove_file(mors->dev, &dev_attr_board_type);
	device_remove_file(mors->dev, &dev_attr_countries);
	if (gpio_is_valid(mors->cfg->mm_4v3_fem_gpio))
		device_remove_file(mors->dev, &dev_attr_mm_4v3_fem);
}
