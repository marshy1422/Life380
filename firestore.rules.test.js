/**
 * Firebase Security Rules Test Suite for Life380
 *
 * Run with: firebase emulators:exec --only firestore "npm test"
 *
 * Prerequisites:
 *   npm install --save-dev @firebase/rules-unit-testing mocha
 */

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment
} = require("@firebase/rules-unit-testing");
const { doc, setDoc, getDoc, updateDoc, deleteDoc, collection, addDoc, serverTimestamp } = require("firebase/firestore");
const fs = require("fs");

const PROJECT_ID = "life380-test";

let testEnv;

// Test user IDs
const USER_ALICE = "alice123";
const USER_BOB = "bob456";
const USER_CHARLIE = "charlie789";
const USER_MALLORY = "mallory666"; // Attacker

// Test circle ID
const CIRCLE_ID = "family-circle-1";

describe("Life380 Firestore Security Rules", () => {

  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules: fs.readFileSync("firestore.rules", "utf8"),
        host: "localhost",
        port: 8080
      }
    });
  });

  after(async () => {
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  // ==========================================
  // USER PROFILE TESTS
  // ==========================================

  describe("User Profiles", () => {

    it("should allow user to create their own profile", async () => {
      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();

      await assertSucceeds(
        setDoc(doc(aliceDb, "users", USER_ALICE), {
          id: USER_ALICE,
          email: "alice@example.com",
          displayName: "Alice",
          circleIds: []
        })
      );
    });

    it("should NOT allow user to create profile for someone else", async () => {
      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();

      await assertFails(
        setDoc(doc(aliceDb, "users", USER_BOB), {
          id: USER_BOB,
          email: "bob@example.com",
          displayName: "Bob",
          circleIds: []
        })
      );
    });

    it("should NOT allow user to create profile with mismatched ID", async () => {
      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();

      await assertFails(
        setDoc(doc(aliceDb, "users", USER_ALICE), {
          id: "different-id",
          email: "alice@example.com",
          displayName: "Alice",
          circleIds: []
        })
      );
    });

    it("should NOT allow creating profile with pre-populated circleIds", async () => {
      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();

      await assertFails(
        setDoc(doc(aliceDb, "users", USER_ALICE), {
          id: USER_ALICE,
          email: "alice@example.com",
          displayName: "Alice",
          circleIds: ["some-circle"] // Should be empty on creation
        })
      );
    });

    it("should allow user to read their own profile", async () => {
      // Setup: Create Alice's profile with admin
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, "users", USER_ALICE), {
          id: USER_ALICE,
          email: "alice@example.com",
          displayName: "Alice",
          circleIds: []
        });
      });

      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();
      await assertSucceeds(getDoc(doc(aliceDb, "users", USER_ALICE)));
    });

    it("should NOT allow user to read another user's profile (not in same circle)", async () => {
      // Setup: Create Bob's profile
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, "users", USER_BOB), {
          id: USER_BOB,
          email: "bob@example.com",
          displayName: "Bob",
          circleIds: []
        });
        await setDoc(doc(adminDb, "users", USER_ALICE), {
          id: USER_ALICE,
          email: "alice@example.com",
          displayName: "Alice",
          circleIds: []
        });
      });

      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();
      await assertFails(getDoc(doc(aliceDb, "users", USER_BOB)));
    });

    it("should allow user to update their own profile", async () => {
      // Setup
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, "users", USER_ALICE), {
          id: USER_ALICE,
          email: "alice@example.com",
          displayName: "Alice",
          circleIds: []
        });
      });

      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();
      await assertSucceeds(
        updateDoc(doc(aliceDb, "users", USER_ALICE), {
          displayName: "Alice Smith",
          latitude: 37.7749,
          longitude: -122.4194
        })
      );
    });

    it("should NOT allow user to change their email", async () => {
      // Setup
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, "users", USER_ALICE), {
          id: USER_ALICE,
          email: "alice@example.com",
          displayName: "Alice",
          circleIds: []
        });
      });

      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();
      await assertFails(
        updateDoc(doc(aliceDb, "users", USER_ALICE), {
          email: "hacked@evil.com"
        })
      );
    });

    it("should NOT allow invalid latitude values", async () => {
      // Setup
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, "users", USER_ALICE), {
          id: USER_ALICE,
          email: "alice@example.com",
          displayName: "Alice",
          circleIds: []
        });
      });

      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();
      await assertFails(
        updateDoc(doc(aliceDb, "users", USER_ALICE), {
          latitude: 200 // Invalid - must be -90 to 90
        })
      );
    });

    it("should NOT allow unauthenticated access", async () => {
      const unauthDb = testEnv.unauthenticatedContext().firestore();
      await assertFails(getDoc(doc(unauthDb, "users", USER_ALICE)));
    });
  });

  // ==========================================
  // CIRCLE TESTS
  // ==========================================

  describe("Circles", () => {

    it("should allow authenticated user to create a circle", async () => {
      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();

      await assertSucceeds(
        setDoc(doc(aliceDb, "circles", CIRCLE_ID), {
          id: CIRCLE_ID,
          name: "Family",
          createdBy: USER_ALICE,
          memberIds: [USER_ALICE],
          inviteCode: "ABC123",
          createdAt: serverTimestamp()
        })
      );
    });

    it("should NOT allow creating circle with someone else as creator", async () => {
      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();

      await assertFails(
        setDoc(doc(aliceDb, "circles", CIRCLE_ID), {
          id: CIRCLE_ID,
          name: "Fake Circle",
          createdBy: USER_BOB, // Alice trying to impersonate Bob
          memberIds: [USER_BOB],
          inviteCode: "ABC123",
          createdAt: serverTimestamp()
        })
      );
    });

    it("should NOT allow creating circle with invalid invite code length", async () => {
      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();

      await assertFails(
        setDoc(doc(aliceDb, "circles", CIRCLE_ID), {
          id: CIRCLE_ID,
          name: "Family",
          createdBy: USER_ALICE,
          memberIds: [USER_ALICE],
          inviteCode: "AB", // Too short
          createdAt: serverTimestamp()
        })
      );
    });

    it("should allow circle member to read circle", async () => {
      // Setup: Create circle with Alice
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, "circles", CIRCLE_ID), {
          id: CIRCLE_ID,
          name: "Family",
          createdBy: USER_ALICE,
          memberIds: [USER_ALICE],
          inviteCode: "ABC123",
          createdAt: new Date()
        });
      });

      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();
      await assertSucceeds(getDoc(doc(aliceDb, "circles", CIRCLE_ID)));
    });

    it("should NOT allow non-member to read circle (SECURITY FIX VERIFICATION)", async () => {
      // Setup: Create circle with Alice only
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, "circles", CIRCLE_ID), {
          id: CIRCLE_ID,
          name: "Family",
          createdBy: USER_ALICE,
          memberIds: [USER_ALICE],
          inviteCode: "SECRET",
          createdAt: new Date()
        });
      });

      // Mallory (not a member) tries to read the circle
      const malloryDb = testEnv.authenticatedContext(USER_MALLORY).firestore();
      await assertFails(getDoc(doc(malloryDb, "circles", CIRCLE_ID)));
    });

    it("should only allow creator to delete circle", async () => {
      // Setup
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, "circles", CIRCLE_ID), {
          id: CIRCLE_ID,
          name: "Family",
          createdBy: USER_ALICE,
          memberIds: [USER_ALICE], // Only Alice
          inviteCode: "ABC123",
          createdAt: new Date()
        });
      });

      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();
      await assertSucceeds(deleteDoc(doc(aliceDb, "circles", CIRCLE_ID)));
    });

    it("should NOT allow creator to delete circle with other members", async () => {
      // Setup
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, "circles", CIRCLE_ID), {
          id: CIRCLE_ID,
          name: "Family",
          createdBy: USER_ALICE,
          memberIds: [USER_ALICE, USER_BOB], // Two members
          inviteCode: "ABC123",
          createdAt: new Date()
        });
      });

      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();
      await assertFails(deleteDoc(doc(aliceDb, "circles", CIRCLE_ID)));
    });
  });

  // ==========================================
  // ENCRYPTED LOCATIONS TESTS (NEW)
  // ==========================================

  describe("Encrypted Locations", () => {

    beforeEach(async () => {
      // Setup: Create circle with Alice and Bob
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, "circles", CIRCLE_ID), {
          id: CIRCLE_ID,
          name: "Family",
          createdBy: USER_ALICE,
          memberIds: [USER_ALICE, USER_BOB],
          inviteCode: "ABC123",
          createdAt: new Date()
        });
      });
    });

    it("should allow circle member to write their own encrypted location", async () => {
      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();

      await assertSucceeds(
        setDoc(doc(aliceDb, "circles", CIRCLE_ID, "encrypted_locations", USER_ALICE), {
          encryptedPayload: new Uint8Array([1, 2, 3, 4]),
          nonce: new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]),
          tag: new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]),
          keyVersion: 1,
          timestamp: serverTimestamp(),
          expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
          privacyLevel: "precise"
        })
      );
    });

    it("should NOT allow circle member to write someone else's encrypted location", async () => {
      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();

      await assertFails(
        setDoc(doc(aliceDb, "circles", CIRCLE_ID, "encrypted_locations", USER_BOB), {
          encryptedPayload: new Uint8Array([1, 2, 3]),
          nonce: new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]),
          tag: new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]),
          keyVersion: 1,
          timestamp: serverTimestamp(),
          expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
        })
      );
    });

    it("should allow circle member to read any member's encrypted location", async () => {
      // Setup: Add Bob's location
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, "circles", CIRCLE_ID, "encrypted_locations", USER_BOB), {
          encryptedPayload: new Uint8Array([1, 2, 3]),
          nonce: new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]),
          tag: new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]),
          keyVersion: 1,
          timestamp: new Date(),
          expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
        });
      });

      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();
      await assertSucceeds(
        getDoc(doc(aliceDb, "circles", CIRCLE_ID, "encrypted_locations", USER_BOB))
      );
    });

    it("should NOT allow non-member to read encrypted locations", async () => {
      const malloryDb = testEnv.authenticatedContext(USER_MALLORY).firestore();

      await assertFails(
        getDoc(doc(malloryDb, "circles", CIRCLE_ID, "encrypted_locations", USER_ALICE))
      );
    });

    it("should allow user to delete their own location data (privacy right)", async () => {
      // Setup
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, "circles", CIRCLE_ID, "encrypted_locations", USER_ALICE), {
          encryptedPayload: new Uint8Array([1, 2, 3]),
          nonce: new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]),
          tag: new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]),
          keyVersion: 1,
          timestamp: new Date(),
          expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
        });
      });

      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();
      await assertSucceeds(
        deleteDoc(doc(aliceDb, "circles", CIRCLE_ID, "encrypted_locations", USER_ALICE))
      );
    });
  });

  // ==========================================
  // SOS ALERTS TESTS
  // ==========================================

  describe("SOS Alerts", () => {

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, "circles", CIRCLE_ID), {
          id: CIRCLE_ID,
          name: "Family",
          createdBy: USER_ALICE,
          memberIds: [USER_ALICE, USER_BOB],
          inviteCode: "ABC123",
          createdAt: new Date()
        });
      });
    });

    it("should allow member to create SOS alert for themselves", async () => {
      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();

      await assertSucceeds(
        setDoc(doc(aliceDb, "circles", CIRCLE_ID, "sosAlerts", "alert1"), {
          id: "alert1",
          userId: USER_ALICE,
          userName: "Alice",
          latitude: 37.7749,
          longitude: -122.4194,
          batteryLevel: 50,
          isActive: true,
          timestamp: serverTimestamp()
        })
      );
    });

    it("should NOT allow member to create SOS alert for someone else", async () => {
      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();

      await assertFails(
        setDoc(doc(aliceDb, "circles", CIRCLE_ID, "sosAlerts", "alert1"), {
          id: "alert1",
          userId: USER_BOB, // Alice trying to create alert as Bob
          userName: "Bob",
          latitude: 37.7749,
          longitude: -122.4194,
          batteryLevel: 50,
          isActive: true,
          timestamp: serverTimestamp()
        })
      );
    });

    it("should NOT allow creating SOS alert with invalid coordinates", async () => {
      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();

      await assertFails(
        setDoc(doc(aliceDb, "circles", CIRCLE_ID, "sosAlerts", "alert1"), {
          id: "alert1",
          userId: USER_ALICE,
          userName: "Alice",
          latitude: 999, // Invalid
          longitude: -122.4194,
          batteryLevel: 50,
          isActive: true,
          timestamp: serverTimestamp()
        })
      );
    });

    it("should allow any circle member to resolve SOS alert", async () => {
      // Setup: Create active alert from Alice
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, "circles", CIRCLE_ID, "sosAlerts", "alert1"), {
          id: "alert1",
          userId: USER_ALICE,
          userName: "Alice",
          latitude: 37.7749,
          longitude: -122.4194,
          batteryLevel: 50,
          isActive: true,
          timestamp: new Date()
        });
      });

      // Bob resolves Alice's alert
      const bobDb = testEnv.authenticatedContext(USER_BOB).firestore();
      await assertSucceeds(
        updateDoc(doc(bobDb, "circles", CIRCLE_ID, "sosAlerts", "alert1"), {
          isActive: false,
          resolvedBy: USER_BOB,
          resolvedAt: serverTimestamp(),
          // Must preserve identity fields
          userId: USER_ALICE,
          userName: "Alice"
        })
      );
    });

    it("should NOT allow changing userId when resolving alert (SECURITY FIX)", async () => {
      // Setup
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, "circles", CIRCLE_ID, "sosAlerts", "alert1"), {
          id: "alert1",
          userId: USER_ALICE,
          userName: "Alice",
          latitude: 37.7749,
          longitude: -122.4194,
          batteryLevel: 50,
          isActive: true,
          timestamp: new Date()
        });
      });

      const bobDb = testEnv.authenticatedContext(USER_BOB).firestore();
      await assertFails(
        updateDoc(doc(bobDb, "circles", CIRCLE_ID, "sosAlerts", "alert1"), {
          isActive: false,
          resolvedBy: USER_BOB,
          resolvedAt: serverTimestamp(),
          userId: USER_BOB, // Trying to change ownership - BLOCKED
          userName: "Alice"
        })
      );
    });

    it("should NEVER allow deletion of SOS alerts", async () => {
      // Setup
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, "circles", CIRCLE_ID, "sosAlerts", "alert1"), {
          id: "alert1",
          userId: USER_ALICE,
          userName: "Alice",
          latitude: 37.7749,
          longitude: -122.4194,
          batteryLevel: 50,
          isActive: false,
          timestamp: new Date()
        });
      });

      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();
      await assertFails(
        deleteDoc(doc(aliceDb, "circles", CIRCLE_ID, "sosAlerts", "alert1"))
      );
    });
  });

  // ==========================================
  // PLACES TESTS
  // ==========================================

  describe("Places", () => {

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, "circles", CIRCLE_ID), {
          id: CIRCLE_ID,
          name: "Family",
          createdBy: USER_ALICE,
          memberIds: [USER_ALICE, USER_BOB],
          inviteCode: "ABC123",
          createdAt: new Date()
        });
      });
    });

    it("should allow circle member to create place", async () => {
      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();

      await assertSucceeds(
        setDoc(doc(aliceDb, "circles", CIRCLE_ID, "places", "place1"), {
          id: "place1",
          name: "Home",
          latitude: 37.7749,
          longitude: -122.4194,
          radius: 100,
          createdBy: USER_ALICE
        })
      );
    });

    it("should NOT allow creating place with invalid coordinates", async () => {
      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();

      await assertFails(
        setDoc(doc(aliceDb, "circles", CIRCLE_ID, "places", "place1"), {
          id: "place1",
          name: "Home",
          latitude: -100, // Invalid
          longitude: -122.4194,
          radius: 100,
          createdBy: USER_ALICE
        })
      );
    });

    it("should NOT allow creating place with name too long", async () => {
      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();

      await assertFails(
        setDoc(doc(aliceDb, "circles", CIRCLE_ID, "places", "place1"), {
          id: "place1",
          name: "A".repeat(101), // Too long
          latitude: 37.7749,
          longitude: -122.4194,
          radius: 100,
          createdBy: USER_ALICE
        })
      );
    });
  });

  // ==========================================
  // CHECK-INS TESTS
  // ==========================================

  describe("Check-Ins", () => {

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, "circles", CIRCLE_ID), {
          id: CIRCLE_ID,
          name: "Family",
          createdBy: USER_ALICE,
          memberIds: [USER_ALICE, USER_BOB],
          inviteCode: "ABC123",
          createdAt: new Date()
        });
      });
    });

    it("should allow member to create check-in for themselves", async () => {
      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();

      await assertSucceeds(
        addDoc(collection(aliceDb, "circles", CIRCLE_ID, "checkIns"), {
          userId: USER_ALICE,
          userName: "Alice",
          type: "safe",
          timestamp: serverTimestamp()
        })
      );
    });

    it("should NOT allow member to create check-in for someone else", async () => {
      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();

      await assertFails(
        addDoc(collection(aliceDb, "circles", CIRCLE_ID, "checkIns"), {
          userId: USER_BOB,
          userName: "Bob",
          type: "safe",
          timestamp: serverTimestamp()
        })
      );
    });

    it("should NEVER allow deletion of check-ins", async () => {
      // Setup
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, "circles", CIRCLE_ID, "checkIns", "checkin1"), {
          userId: USER_ALICE,
          userName: "Alice",
          type: "safe",
          timestamp: new Date()
        });
      });

      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();
      await assertFails(
        deleteDoc(doc(aliceDb, "circles", CIRCLE_ID, "checkIns", "checkin1"))
      );
    });
  });

  // ==========================================
  // SUBSCRIPTION PROTECTION TESTS
  // ==========================================

  describe("Subscriptions", () => {

    it("should allow user to read their own subscription", async () => {
      // Setup
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, "subscriptions", USER_ALICE), {
          tier: "plus",
          expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
        });
      });

      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();
      await assertSucceeds(getDoc(doc(aliceDb, "subscriptions", USER_ALICE)));
    });

    it("should NOT allow user to read another user's subscription", async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, "subscriptions", USER_BOB), {
          tier: "family",
          expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
        });
      });

      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();
      await assertFails(getDoc(doc(aliceDb, "subscriptions", USER_BOB)));
    });

    it("should NOT allow users to write subscription data", async () => {
      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();

      await assertFails(
        setDoc(doc(aliceDb, "subscriptions", USER_ALICE), {
          tier: "family", // Trying to give themselves premium
          expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000)
        })
      );
    });
  });

  // ==========================================
  // DENY-ALL CATCH-ALL TESTS
  // ==========================================

  describe("Catch-All Deny Rule", () => {

    it("should deny access to unknown collections", async () => {
      const aliceDb = testEnv.authenticatedContext(USER_ALICE).firestore();

      await assertFails(
        setDoc(doc(aliceDb, "secretData", "doc1"), {
          data: "hacked"
        })
      );
    });

    it("should deny unauthenticated access everywhere", async () => {
      const unauthDb = testEnv.unauthenticatedContext().firestore();

      await assertFails(getDoc(doc(unauthDb, "users", USER_ALICE)));
      await assertFails(getDoc(doc(unauthDb, "circles", CIRCLE_ID)));
    });
  });

});
