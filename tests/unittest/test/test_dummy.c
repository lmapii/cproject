/**
 * \file test_dummy.c
 */

#include "unity.h"

#include "dummy/dummy.h"

void setUp(void)
{
}

void tearDown(void)
{
}

void test_dummy(void)
{
    TEST_ASSERT_EQUAL(4U, dummy_random());
}
