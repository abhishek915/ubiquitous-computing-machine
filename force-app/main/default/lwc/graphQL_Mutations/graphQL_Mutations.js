import { LightningElement } from "lwc";
import { gql, executeMutation } from "lightning/graphql";
import { NavigationMixin } from "lightning/navigation";

export default class GraphQL_Mutations extends NavigationMixin(
  LightningElement
) {
  firstName = "";
  lastName = "";
  title = "";
  email = "";
  phone = "";

  charactersOnlyPattern = /^[A-Za-z ]+$/;
  emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  usPhonePattern =
    /^(\+1\s?)?(\([2-9][0-9]{2}\)|[2-9][0-9]{2})[-.\s]?[2-9][0-9]{2}[-.\s]?[0-9]{4}$/;

  get isCreateDisabled() {
    const textFieldsAreValid = [
      this.firstName,
      this.lastName,
      this.title
    ].every((value) => this.charactersOnlyPattern.test(value.trim()));

    return (
      !textFieldsAreValid ||
      !this.emailPattern.test(this.email.trim()) ||
      !this.usPhonePattern.test(this.phone.trim())
    );
  }

  get createMutation() {
    return gql`
      mutation ContactCreateExample($input: ContactCreateInput!) {
        uiapi {
          ContactCreate(input: $input) {
            Record {
              Id
              Name {
                value
              }
            }
          }
        }
      }
    `;
  }

  handleInputChange(event) {
    const field = event.target.dataset.field;
    this[field] = event.target.value;
  }

  async handleCreateContact() {
    const isValid = [
      ...this.template.querySelectorAll("lightning-input")
    ].reduce((validSoFar, input) => input.reportValidity() && validSoFar, true);

    if (!isValid) {
      return;
    }

    try {
      const result = await executeMutation({
        query: this.createMutation,
        variables: {
          input: {
            Contact: {
              FirstName: this.firstName,
              LastName: this.lastName,
              Title: this.title,
              Email: this.email,
              Phone: this.phone
            }
          }
        }
      });

      console.log("Contact created", result);

      const contactId = result?.data?.uiapi?.ContactCreate?.Record?.Id;
      if (contactId) {
        this[NavigationMixin.Navigate]({
          type: "standard__recordPage",
          attributes: {
            recordId: contactId,
            objectApiName: "Contact",
            actionName: "view"
          }
        });
      }
    } catch (error) {
      console.error("Error creating contact", error);
    }
  }
}
