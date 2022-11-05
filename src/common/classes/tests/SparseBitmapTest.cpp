#include "firebird.h"
#include "boost/test/unit_test.hpp"
#include "../common/classes/alloc.h"
#include "../common/classes/tree.h"
#include "../common/classes/sparse_bitmap.h"

using namespace Firebird;

BOOST_AUTO_TEST_SUITE(CommonSuite)
BOOST_AUTO_TEST_SUITE(SparseBitmapSuite)


BOOST_AUTO_TEST_SUITE(SparseBitmapTests)

BOOST_AUTO_TEST_CASE(ConstructionWithMemoryPool)
{
	SparseBitmap<ULONG> bitmap(*getDefaultMemoryPool());

	bitmap.set(0);
	bitmap.set(100);
	bitmap.set(10000);

	for (size_t i = 0; i <= 10100; i++)
	{
		switch (i)
		{
			case 0:
			case 100:
			case 10000:
				BOOST_TEST(bitmap.test(i) == true);
				break;
			default:
				BOOST_TEST(bitmap.test(i) == false);
		}
	}
}

BOOST_AUTO_TEST_CASE(bitOr)
{
	SparseBitmap<ULONG> A(*getDefaultMemoryPool());
	SparseBitmap<ULONG> B(*getDefaultMemoryPool());

	A.set(1);
	A.set(100);
	A.set(10000);

	B.set(10);
	B.set(100);
	B.set(1000);


	auto bitmapA = &A;
	auto bitmapB = &B;

	auto C = *SparseBitmap<ULONG>::bit_or(&bitmapA, &bitmapB);
	BOOST_TEST(C != nullptr);

	for (size_t i = 0; i <= 10100; i++)
	{
		switch (i)
		{
			case 1:
			case 10:
			case 100:
			case 1000:
			case 10000:
				BOOST_TEST(C->test(i) == true);
				break;
			default:
				BOOST_TEST(C->test(i) == false);
		}
	}
}

BOOST_AUTO_TEST_CASE(bitAnd)
{
	SparseBitmap<ULONG> A(*getDefaultMemoryPool());
	SparseBitmap<ULONG> B(*getDefaultMemoryPool());

	A.set(1);
	A.set(100);
	A.set(10000);

	B.set(10);
	B.set(100);
	B.set(1000);


	auto bitmapA = &A;
	auto bitmapB = &B;

	auto C = *SparseBitmap<ULONG>::bit_and(&bitmapA, &bitmapB);
	BOOST_TEST(C != nullptr);

	for (size_t i = 0; i <= 10100; i++)
	{
		switch (i)
		{
			case 100:
				BOOST_TEST(C->test(i) == true);
				break;
			default:
				BOOST_TEST(C->test(i) == false);
		}
	}
}

BOOST_AUTO_TEST_CASE(bitSubtract)
{
	SparseBitmap<ULONG> A(*getDefaultMemoryPool());
	SparseBitmap<ULONG> B(*getDefaultMemoryPool());

	A.set(1);
	A.set(100);
	A.set(101);
	A.set(10000);

	B.set(10);
	B.set(100);
	B.set(1000);


	auto bitmapA = &A;
	auto bitmapB = &B;

	auto C = *SparseBitmap<ULONG>::bit_subtract(&bitmapA, &bitmapB);
	BOOST_TEST(C != nullptr);

	for (size_t i = 0; i <= 10100; i++)
	{
		switch (i)
		{
			case 1:
			case 101:
			case 10000:
				BOOST_TEST(C->test(i) == true);
				break;
			default:
				BOOST_TEST(C->test(i) == false);
		}
	}
}


BOOST_AUTO_TEST_SUITE_END()	// SortedArrayTests


BOOST_AUTO_TEST_SUITE_END()	// ArraySuite
BOOST_AUTO_TEST_SUITE_END()	// CommonSuite
